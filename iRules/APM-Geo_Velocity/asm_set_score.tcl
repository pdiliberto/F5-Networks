when RULE_INIT {
 set static::max_violations 1024
}

when ASM_REQUEST_VIOLATION
{
    log local0. "ASM REQUEST DONE result: [ASM::status]"
    if { [ASM::status] equals "blocked" || [ASM::status] equals "alarmed" } {
        #get violation details
        log local0. "ASM VIOLATION!"
        set vdetails [ASM::violation_data]
        set srcip [lindex $vdetails 4]
        
        #verify src IP in  violators table and update the table accordingly
        set ipviolations [table lookup -subtable "violators" $srcip]
        if { $ipviolations != "" } {
            log local0. "User with ip address $srcip has already $ipviolations violations"
            if { $ipviolations < $static::max_violations } { incr ipviolations }
            log local0. "Tabled updated with $ipviolations violations"
            table replace -subtable "violators" $srcip $ipviolations 1800
        }
        else {
            log local0. "This is the first violation from IP $srcip. Adding a Table record"
            table set -subtable "violators" $srcip 1 1800
        }

        #verify if an APM session exists, and store the bad username. Requires Session Tracking with APM+ASM VS
        if { [HTTP::header exists session-id] } { 
            log local0. "APM Session exists"
            set baduser [HTTP::header value username]
        }
        else {
            # verify if an APM session exists. ASM Virtual-to-APM Virtual Use case
            if { [HTTP::cookie exists LastMRH_Session] } { 
                set sid [ACCESS::session sid]
                set baduser [ACCESS::session data get -sid $sid "session.logon.last.username"]
            }
        }
        if { $baduser != "" } {
            # check against APM violators and update the table accordingly
            log local0. "violation from APM session: $baduser"
            set usersviolations [table lookup -subtable "badusers" $baduser]
            if { $usersviolations != "" } {
                log local0. "User $baduser has already $usersviolations violations"
                if { $usersviolations < $static::max_violations } { incr usersviolations }
                table replace -subtable "badusers" $baduser $usersviolations 1800
                log local0. "Table updated with $usersviolations violations"
            }
            else {
                log local0. "This is the first violation from APM user $baduser. Adding a Table record"
                table set -subtable "badusers" $baduser 1 1800
            }
        }
    }
}

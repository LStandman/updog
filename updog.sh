#!/usr/bin/expect -f

set timeout 10

proc notify {} {
  exec sendmail nobody@example.com << [string cat \
    "From: <>\r\n" \
    "Reply-To: <>\r\n" \
    "To: <>\r\n" \
    "Subject: ***DOWNTIME WARNING***\r\n" \
    "\r\n" \
    "Domain \"example\" appears to be down.\r\n" \
  ]
}

proc maybenotify {} {
  set lastmail "/var/local/updog/lastmail"

  try {
    set atime [file atime $lastmail]
  } trap {POSIX ENOENT} {} {
    close [open $lastmail w]
    set atime 0
  }

  set now [clock seconds]

  if {[clock add $atime 11 hours] < $now} {
    notify
    file atime $lastmail $now
  }
}

proc smtp {host port} {
  set result 1

  spawn telnet $host $port
  expect {
    "220" {
      set result 0
      send "QUIT\r"
      expect "221"
    }
    timeout {
      # Send ^C
      send "\003\r"
      expect eof
    }
  }

  close
  wait

  return $result
}

set host "example"
set port "25"

set numdcs 0

while {1} {
  if {[smtp $host $port] == 0} {
    set numdcs 0
  } else {
    incr numdcs
  }

  if {$numdcs == 0} {
    # normally test every 1hr
    after [expr {1000 * 60 * 60}]
  } elseif {$numdcs < 3} {
    # test for 3 failures total within 10 min
    # (X -5min- X -5min- X)
    after [expr {1000 * 60 * 5}]
  } else {
    maybenotify

    set numdcs 4
    after [expr {1000 * 60 * 60}]
  }
}
import os
import streams
import osproc
import strutils
import sequtils, sugar
import parseopt
import strformat

var
    logstrm:Stream = newStringStream()
    logfile        = ""
    # fstrm          = newFileStream("pbox.logcat.log", fmWrite)
    line           = ""
    echoing        = false
    daemon         = false
    targetSerial   = ""

proc getDeviceIds(): seq =
    let p = startProcess(
        "adb", args=["devices"], options={poUsePath}
    )
    defer: p.close()
    var ls = toSeq(lines(outputStream(p)))
    ls.delete(0)
    return ls
        .map(li => strip(split(li)[0]))
        .filter(d => d != "")

proc hasDevice(): bool = getDeviceIds().len > 0

proc runAdbLogcat(serial: string = ""): Process =
    var opts = {poUsePath}
    if daemon:
        opts = opts + {poDaemon}

    echo("opts", opts)
    let process = startProcess(
        "adb",
        args=["logcat"],
        options=opts
    )
    logstrm = outputStream(process)
    return process


proc main() =
    if not hasDevice():
        echo("No device connected")
        return

    let cmd: string = commandLineParams().join(" ")
    var p = initOptParser(cmd)
    while true:
        p.next()
        case p.kind
        of cmdEnd: break
        of cmdShortOption, cmdLongOption:
            case p.key
            of "d", "daemon":
                echo "daemon"
                if p.val.len > 0:
                    daemon = parseBool(p.val)
                else:
                    daemon = true
            of "e", "echo":
                if p.val.len > 0:
                    echoing = parseBool(p.val)
                else:
                    echoing = true
            of "s", "serial":
                targetSerial = p.val
        of cmdArgument:
            targetSerial = p.key

    var serials = newSeq[string]()
    if targetSerial.len > 0:
        serials.add(targetSerial)
    else:
        serials = getDeviceIds()

    logfile = &"pbox.logcat.{serials[0]}.out.log"
    let po = runAdbLogcat()
    defer: po.close()

    let fstrm = newFileStream(logfile, fmWrite)

    if not isNil(logstrm):
        while logstrm.readLine(line):
            if echoing:
                echo(line)
            fstrm.writeLine(line)


when isMainModule:
    main()

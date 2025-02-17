open Nonstd
module String = Sosa.Native_string

let ( // ) = Filename.concat

module Shell_script = struct
  type t = {name: string; content: unit Genspio.EDSL.t; dependencies: t list}

  open Genspio.EDSL

  let make ?(dependencies = []) name content = {name; content; dependencies}

  let sanitize_name n =
    let m =
      String.map n ~f:(function
        | ('0' .. '9' | 'a' .. 'z' | 'A' .. 'Z' | '-') as c -> c
        | other -> '_' )
    in
    String.sub ~index:0 ~length:40 m |> Option.value ~default:m

  let path {name; content} =
    let hash =
      Marshal.to_string content [] |> Digest.string |> Digest.to_hex
    in
    let tag = String.sub_exn ~index:0 hash ~length:8 in
    "_scripts" // sprintf "%s_%s.sh" (sanitize_name name) tag

  let call f = exec ["sh"; path f]

  type compiled =
    {files: (string * string list) list; call: unit Genspio.EDSL.t}

  let rec compile ({name; content; dependencies} as s) =
    let filename = path s in
    let dep_scripts = List.map ~f:compile dependencies in
    (* dbg "name %s filename: %s" name filename; *)
    { files=
        ( filename
        , [ "# Script %s"
          ; "# Generated by Genspio"
          ; sprintf "echo 'Genspio.Shell_script: %s (%s)'" name filename
          ; Genspio.Compile.to_many_lines content ] )
        :: List.concat_map dep_scripts ~f:(fun c -> c.files)
    ; call= call s }
end

module Run_environment = struct
  module File = struct
    type t = Http of string * [`Xz] option

    let local_file_name =
      let noquery url = String.split ~on:(`Character '?') url |> List.hd_exn in
      function
      | Http (url, None) -> "_cache" // Filename.basename (noquery url)
      | Http (url, Some `Xz) ->
          "_cache"
          // Filename.(basename (noquery url) |> fun f -> chop_suffix f ".xz")

    let tmp_name_of_url = function
      | Http (url, ext) ->
          ("_cache" // Digest.(string url |> to_hex))
          ^ Option.value_map ~default:"" ext ~f:(fun `Xz -> ".xz")

    let make_files files =
      List.map files ~f:(function Http (url, act) as t ->
          let base = local_file_name t in
          let wget =
            let open Shell_script in
            let open Genspio.EDSL in
            check_sequence
              [ ("mkdir", exec ["mkdir"; "-p"; "_cache"])
              ; ( "wget"
                , exec ["wget"; url; "--output-document"; tmp_name_of_url t] )
              ; ( "act-and-mv"
                , match act with
                  | None -> exec ["mv"; "-f"; tmp_name_of_url t; base]
                  | Some `Xz ->
                      seq
                        [ exec ["unxz"; "-k"; tmp_name_of_url t]
                        ; exec
                            [ "mv"
                            ; "-f"
                            ; Filename.chop_suffix (tmp_name_of_url t) ".xz"
                            ; base ] ] ) ]
          in
          (base, [], wget) )
  end

  module Ssh = struct
    let ssh_options =
      [ "-oStrictHostKeyChecking=no"
      ; "-oGlobalKnownHostsFile=/dev/null"
      ; "-oUserKnownHostsFile=/dev/null" ]

    let host_file f = sprintf "root@localhost:%s" f

    let sshpass ?password cmd =
      match password with None -> cmd | Some p -> ["sshpass"; "-p"; p] @ cmd

    let scp ?password ~ssh_port () =
      sshpass ?password @@ ["scp"] @ ssh_options
      @ ["-P"; Int.to_string ssh_port]

    let script_over_ssh ?root_password ~ssh_port ~name script =
      let open Shell_script in
      let open Genspio.EDSL in
      let script_path = path script in
      let tmp = "/tmp" // Filename.basename script_path in
      make ~dependencies:[script] (sprintf "SSH exec %s" name)
      @@ check_sequence
           [ ( "scp"
             , exec
                 ( scp ?password:root_password ~ssh_port ()
                 @ [script_path; host_file tmp] ) )
           ; ( "ssh-exec"
             , exec
                 ( sshpass ?password:root_password
                 @@ ["ssh"] @ ssh_options
                 @ [ "-p"
                   ; Int.to_string ssh_port
                   ; "root@localhost"
                   ; sprintf "sh %s" tmp ] ) ) ]
  end

  type vm =
    | Qemu_arm of
        { kernel: File.t
        ; sd_card: File.t
        ; machine: string
        ; initrd: File.t option
        ; root_device: string }
    | Qemu_amd46 of {hda: File.t; ui: [`No_graphic | `Curses]}

  type t =
    { name: string
    ; root_password: string option
    ; setup: unit Genspio.EDSL.t
    ; ssh_port: int
    ; local_dependencies: [`Command of string] list
    ; vm: vm }

  let make vm ?root_password ?(setup = Genspio.EDSL.nop) ~local_dependencies
      ~ssh_port name =
    {vm; root_password; setup; local_dependencies; name; ssh_port}

  let qemu_arm ~kernel ~sd_card ~machine ?initrd ~root_device =
    make (Qemu_arm {kernel; sd_card; machine; initrd; root_device})

  let qemu_amd46 ?(ui = `No_graphic) ~hda = make (Qemu_amd46 {hda; ui})

  let http ?act uri = File.Http (uri, act)

  let start_qemu_vm : t -> Shell_script.t = function
    | { ssh_port
      ; vm= Qemu_arm {kernel; machine; sd_card; root_device; initrd; _} } ->
        let open Shell_script in
        let open Genspio.EDSL in
        make "Start-qemu-arm"
          (exec
             ( [ "qemu-system-arm"
               ; "-M"
               ; machine
               ; "-m"
               ; "1024M"
               ; "-kernel"
               ; File.local_file_name kernel ]
             @ Option.value_map initrd ~default:[] ~f:(fun f ->
                   ["-initrd"; File.local_file_name f] )
             @ [ "-pidfile"
               ; "qemu.pid"
               ; "-net"
               ; "nic"
               ; "-net"
               ; sprintf "user,hostfwd=tcp::%d-:22" ssh_port
               ; "-nographic"
               ; "-sd"
               ; File.local_file_name sd_card
               ; "-append"
               ; sprintf "console=ttyAMA0 verbose debug root=%s" root_device ]
             ))
    | {ssh_port; vm= Qemu_amd46 {hda; ui}} ->
        (* See https://wiki.qemu.org/Hosts/BSD
         qemu-system-x86_64 -m 2048 \
          -hda FreeBSD-11.0-RELEASE-amd64.qcow2 -enable-kvm \
          -netdev user,id=mynet0,hostfwd=tcp:127.0.0.1:7722-:22 \
          -device e1000,netdev=mynet0 *)
        let open Shell_script in
        let open Genspio.EDSL in
        make "Start-qemu"
          (exec
             ( [ "qemu-system-x86_64" (* ; "-M"
                * ; machine *)
               ; "-m"
               ; "1024M" (* ; "-enable-kvm" → requires `sudo`?*)
               ; "-hda"
               ; File.local_file_name hda ]
             @ [ "-pidfile"
               ; "qemu.pid"
               ; "-netdev"
               ; sprintf "user,id=mynet0,hostfwd=tcp::%d-:22" ssh_port
               ; ( match ui with
                 | `Curses -> "-curses"
                 | `No_graphic -> "-nographic" )
               ; "-device"
               ; "e1000,netdev=mynet0" ] ))

  let kill_qemu_vm : t -> Shell_script.t = function
    | {name} ->
        let open Shell_script in
        let open Genspio.EDSL in
        let pid = get_stdout (exec ["cat"; "qemu.pid"]) in
        Shell_script.(make (sprintf "kill-qemu-%s" name))
        @@ check_sequence
             (* ~name:(sprintf "Killing Qemu VM")
       * ~clean_up:[fail "kill_qemu_vm"] *)
             [ ( "Kill-qemu-vm"
               , if_seq
                   (file_exists (string "qemu.pid"))
                   ~t:
                     [ if_seq
                         (call [string "kill"; pid] |> succeeds)
                         ~t:[exec ["rm"; "qemu.pid"]]
                         ~e:
                           [ printf
                               (string
                                  "PID file here (PID: %s) but Kill failed, \
                                   deleting `qemu.pid`")
                               [pid]
                           ; exec ["rm"; "qemu.pid"]
                           ; exec ["false"] ] ]
                   ~e:[printf (string "No PID file") []; exec ["false"]] ) ]

  let configure : t -> Shell_script.t = function
    | {name; local_dependencies} ->
        let open Shell_script in
        let open Genspio.EDSL in
        let report = tmp_file "configure-report.md" in
        let there_was_a_failure = tmp_file "bool-failure" in
        let cmds =
          [ report#set (str "Configuration Report\n====================\n\n")
          ; there_was_a_failure#set (bool false |> Bool.to_string) ]
          @ List.map local_dependencies ~f:(function `Command name ->
                if_seq
                  (exec ["which"; name] |> silently |> succeeds)
                  ~t:[report#append (ksprintf str "* `%s`: found.\n" name)]
                  ~e:
                    [ report#append (ksprintf str "* `%s`: NOT FOUND!\n" name)
                    ; there_was_a_failure#set (bool true |> Bool.to_string) ] )
          @ [ call [string "cat"; report#path]
            ; if_seq
                (there_was_a_failure#get |> Bool.of_string)
                ~t:
                  [ exec ["printf"; "\\nThere were *failures* :(\\n"]
                  ; exec ["false"] ]
                ~e:[exec ["printf"; "\\n*Success!*\\n"]] ]
        in
        Shell_script.(make (sprintf "configure-%s" name))
        @@ check_sequence ~verbosity:`Output_all
             (List.mapi cmds ~f:(fun i c -> (sprintf "config-%s-%d" name i, c)))

  let make_dependencies = function
    | {vm= Qemu_amd46 {hda}} -> File.make_files [hda]
    | {vm= Qemu_arm {kernel; sd_card; initrd}} ->
        File.make_files
          ( [kernel; sd_card]
          @ Option.value_map initrd ~default:[] ~f:(fun x -> [x]) )

  let setup_dir_content tvm =
    let {name; root_password; setup; ssh_port; vm} = tvm in
    let other_files = ref [] in
    let dependencies = make_dependencies tvm in
    let start_deps = List.map dependencies ~f:(fun (base, _, _) -> base) in
    let help_entries = ref [] in
    let make_entry ?doc ?(phony = false) ?(deps = []) target action =
      help_entries := (target, doc) :: !help_entries ;
      (if phony then [sprintf ".PHONY: %s" target] else [])
      @ [ sprintf "# %s: %s" target
            (Option.value_map
               ~f:(String.map ~f:(function '\n' -> ' ' | c -> c))
               doc ~default:"NOT DOCUMENTED")
        ; sprintf "%s: %s" target (String.concat ~sep:" " deps)
        ; sprintf "\t@%s" (Genspio.Compile.to_one_liner ~no_trap:true action)
        ]
    in
    let make_script_entry ?doc ?phony ?deps target script =
      let open Shell_script in
      let {files; call} = Shell_script.compile script in
      other_files := !other_files @ files ;
      make_entry ?doc ?phony ?deps target call
    in
    let makefile =
      ["# Makefile genrated by Genspio's VM-Tester"]
      @ List.concat_map dependencies ~f:(fun (base, deps, cmd) ->
            Shell_script.(make (sprintf "get-%s" (sanitize_name base)) cmd)
            |> make_script_entry ~deps base )
      @ make_script_entry ~phony:true "configure" (configure tvm)
          ~doc:"Configure this local-host (i.e. check for requirements)."
      @ make_script_entry ~deps:start_deps ~phony:true "start"
          ~doc:"Start the Qemu VM (this grabs the terminal)."
          (start_qemu_vm tvm)
      @ make_script_entry ~phony:true "kill" (kill_qemu_vm tvm)
          ~doc:"Kill the Qemu VM."
      @ make_script_entry ~phony:true "setup"
          (Ssh.script_over_ssh ?root_password ~ssh_port ~name:"setup"
             (Shell_script.make (sprintf "setup-%s" name) setup))
          ~doc:
            "Run the “setup” recipe on the Qemu VM (requires the VM\n  \
             started in another terminal)."
      @ make_entry ~phony:true "ssh" ~doc:"Display an SSH command"
          Genspio.EDSL.(
            printf
              (ksprintf string "ssh -p %d %s root@localhost" ssh_port
                 (String.concat ~sep:" " Ssh.ssh_options))
              [])
    in
    let help =
      make_script_entry ~phony:true "help"
        Shell_script.(
          make "Display help message"
            Genspio.EDSL.(
              exec
                [ "printf"
                ; "\\nHelp\\n====\\n\\nThis a generated Makefile (by \
                   Genspio-VM-Tester):\\n\\n%s\\n\\n%s\\n"
                ; List.map
                    ( ("help", Some "Display this help message")
                    :: !help_entries ) ~f:(function
                    | target, None -> ""
                    | target, Some doc ->
                        sprintf "* `make %s`: %s\n" target doc )
                  |> String.concat ~sep:""
                ; sprintf
                    "SSH: the command `make ssh` *outputs* an SSH command \
                     (%s). Examples:\n\n\
                     $ `make ssh` uname -a\n\
                     $ tar c some/dir/ | $(make ssh) 'tar x'\n\n\
                     (may need to be `tar -x -f -` for BSD tar).\n"
                    (Option.value_map ~default:"No root-password" root_password
                       ~f:(sprintf "Root-password: %S")) ]))
    in
    ("Makefile", ("all: help" :: makefile) @ help @ [""]) :: !other_files

  module Example = struct
    let qemu_arm_openwrt ~ssh_port more_setup =
      let setup =
        let open Genspio.EDSL in
        check_sequence
          [ ("opkg-update", exec ["opkg"; "update"])
          ; ("install-od", exec ["opkg"; "install"; "coreutils-od"])
          ; ("install-make", exec ["opkg"; "install"; "make"])
          ; ("additional-setup", more_setup) ]
      in
      let base_url =
        "https://downloads.openwrt.org/snapshots/trunk/realview/generic/"
      in
      qemu_arm "qemu_arm_openwrt" ~ssh_port ~machine:"realview-pbx-a9"
        ~kernel:(http (base_url // "openwrt-realview-vmlinux.elf"))
        ~sd_card:(http (base_url // "openwrt-realview-sdcard.img"))
        ~root_device:"/dev/mmcblk0p1" ~setup
        ~local_dependencies:[`Command "qemu-system-arm"]

    let qemu_arm_wheezy ~ssh_port more_setup =
      (*
         See {{:https://people.debian.org/~aurel32/qemu/armhf/}}.
      *)
      let aurel32 file =
        http ("https://people.debian.org/~aurel32/qemu/armhf" // file)
      in
      let setup =
        let open Genspio.EDSL in
        check_sequence
          [ ("apt-get-make", exec ["apt-get"; "install"; "--yes"; "make"])
          ; ("additional-setup", more_setup) ]
      in
      qemu_arm "qemu_arm_wheezy" ~ssh_port ~machine:"vexpress-a9"
        ~kernel:(aurel32 "vmlinuz-3.2.0-4-vexpress")
        ~sd_card:(aurel32 "debian_wheezy_armhf_standard.qcow2")
        ~initrd:(aurel32 "initrd.img-3.2.0-4-vexpress")
        ~root_device:"/dev/mmcblk0p2" ~root_password:"root" ~setup
        ~local_dependencies:[`Command "qemu-system-arm"; `Command "sshpass"]

    let qemu_amd64_freebsd ~ssh_port more_setup =
      let qcow =
        http ~act:`Xz
          (* This qcow2 was created following the instructions at
             https://wiki.qemu.org/Hosts/BSD#FreeBSD *)
          "https://www.dropbox.com/s/ni7u0k6auqh2lya/FreeBSD11-amd64-rootssh.qcow2.xz?raw=1"
      in
      let setup = more_setup in
      let root_password = "root" in
      qemu_amd46 "qemu_amd64_freebsd" ~hda:qcow ~setup ~root_password
        ~ui:`Curses
        ~local_dependencies:[`Command "qemu-system-x86_64"; `Command "sshpass"]
        ~ssh_port

    let qemu_amd64_darwin ~ssh_port more_setup =
      (*
         Made with these instructions: http://althenia.net/notes/darwin
         from http://www.opensource.apple.com/static/iso/darwinx86-801.iso.gz
      *)
      let qcow =
        http ~act:`Xz
          "https://www.dropbox.com/s/2oeuya0isvorsam/darwin-disk-20180730.qcow2.xz?raw=1"
      in
      let setup = more_setup in
      let root_password = "root" in
      qemu_amd46 "qemu_amd64_darwin" ~hda:qcow ~setup ~root_password
        ~ui:`No_graphic
        ~local_dependencies:[`Command "qemu-system-x86_64"; `Command "sshpass"]
        ~ssh_port
  end
end

let cmdf fmt =
  ksprintf
    (fun cmd ->
      match Sys.command cmd with
      | 0 -> ()
      | other -> ksprintf failwith "Command %S did not return 0: %d" cmd other
      )
    fmt

let write_lines p l =
  let o = open_out p in
  List.iter l ~f:(fprintf o "%s\n") ;
  close_out o

let () =
  let fail fmt =
    ksprintf
      (fun s ->
        eprintf "Wrong CLI: %s\n%!" s ;
        exit 2 )
      fmt
  in
  let args = Array.to_list Sys.argv |> List.tl_exn in
  if List.length args < 2 then fail "Need more args..." else () ;
  let re =
    let more_setup = Genspio.EDSL.(nop) in
    match List.nth_exn args 0 with
    | "arm-owrt" ->
        Run_environment.Example.qemu_arm_openwrt ~ssh_port:20022 more_setup
    | "arm-dw" ->
        Run_environment.Example.qemu_arm_wheezy ~ssh_port:20023 more_setup
    | "amd64-fb" ->
        Run_environment.Example.qemu_amd64_freebsd ~ssh_port:20024 more_setup
    | "amd64-dw" ->
        Run_environment.Example.qemu_amd64_darwin ~ssh_port:20025 more_setup
    | other -> fail "Don't know VM %S" other
  in
  let path = List.nth_exn args 1 in
  let content = Run_environment.setup_dir_content re in
  List.iter content ~f:(fun (filepath, content) ->
      let full = path // filepath in
      cmdf "mkdir -p %s" (Filename.dirname full) ;
      write_lines full content )

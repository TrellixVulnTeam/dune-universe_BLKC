#use "tools/please_lib.ml";;

let version = "0.0.0"

let main_libs = [
  "nonstd";
  "sosa";
  "yojson";
  "atdgen";
]
let main_app_libs = main_libs @ ["rresult"; "misuja"; "cmdliner"]

let config_merlin = Merlin.lines ~s:["."; "tools"] ~pkg:main_libs ()

let meta_content =
  String.concat ~sep:"\n" [
    "(** Metadata Module Generated by the Build System *)";
    "";
    sprintf "let version = %S" version;
  ]

let atd_file = "scene_format.atd"
let scene_lib_jbuilder =
  let open Jbuilder in
  jbuild [
    rule
      ~targets:(List.map ["_t.mli"; "_t.ml"; "_j.ml"; "_j.mli"; "_b.ml"; "_b.mli"]
                  ~f:(sprintf "scene_format%s"))
      ~deps:[atd_file]
      (List.map [
          ["-j-std"; "-j-defaults"; "-j"];
          ["-t"];
          ["-b"];
        ] ~f:(fun opts -> run @@ "atdgen" :: opts @ [atd_file]));
    rule ~targets:["meta.ml"] [
      write_file "meta.ml" meta_content;
    ];
    lib "vecosek_scene" ~deps:main_libs;
  ]

let engine_lib_jbuilder =
  let open Jbuilder in
  jbuild [
    lib "vecosek_engine" ~deps:["vecosek-scene"];
  ]

let main_jbuilder =
  let open Jbuilder in
  jbuild [
    executable "main"
      ~libraries:("vecosek-engine" :: main_app_libs);
    install ~package:"vecosek" ~files:[`As ("main.exe", "vecosek")] ();
  ]

let test_scenes_jbuilder =
  let open Jbuilder in
  jbuild [
    executable "scenes"
      ~libraries:("vecosek_scene" :: ["cmdliner"]);
  ]

let opam_file name deps =
  Opam.make name
    ~opam_version: "1.2"
    ~maintainer:"Seb Mondet <seb@mondet.org>"
    ~homepage: "https://gitlab.com/smondet/vecosek"
    ~license: "ISC"
    ~version
    ~ocaml_min_version:"4.03.0"
    ~deps:(List.map deps ~f:Opam.dep)

let files =
  let open File in
  [
    file ".merlin" config_merlin;
    file "src/lib/jbuild" scene_lib_jbuilder;
    file "src/engine/jbuild" engine_lib_jbuilder;
    file "src/app/jbuild" main_jbuilder;
    file "src/test/jbuild" test_scenes_jbuilder;
    repo_file "vecosek-scene.opam"
      (opam_file "vecosek-scene" main_libs);
    repo_file "vecosek-engine.opam"
      (opam_file "vecosek-engine" ["vecosek-scene"]);
    repo_file "vecosek.opam"
      (opam_file "vecosek" ("vecosek-engine" :: main_app_libs));
  ]

let () =
  Main.make ~files ()
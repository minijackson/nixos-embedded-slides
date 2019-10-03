---
title: NixOS for Embedded systems
author: Rémi Nicole
date: 2019-10-09
slide-level: 2
aspectratio: 169
theme: metropolis
toc: true
highlightstyle: breezedark
lang: en-US

header-includes: |
  \usepackage{csquotes}
  \usepackage{pgfpages}
  \setbeameroption{show notes on second screen=right}

  \usecolortheme{owl}
  \setbeamercolor{section in toc}{
    use=normal text,
    fg=normal text.fg
  }
  \setbeamercolor{subsection in toc}{
    use=normal text,
    fg=normal text.fg
  }

  \usepackage{fvextra}
---

# Projects and concepts

## {.standout}

Heads Up

::: notes

- This is not a "what are you doing not using this" talk
- We will see some drawbacks that makes these tools not suitable for production
  yet.
- This is more a call to try, tinker, experiment, contribute to the project so
  it would be production ready

:::

## Definitions

NixOS

: Distribution

Nix

: Source-based package manager

Nixpkgs

: "Standard library"

::: notes

- All 3 are useful in the Embedded system context

- "Standard library" is quoted, because it contains:

	- Packages
	- Functions
	- Compiling instructions for multiple languages / tools
	- NixOS modules and options

- NixOS is more of a "complete application" of the Nix package manager's
  philosophy, implemented inside Nixpkgs

:::

## Other projects

Hydra

: Continuous Integration server based on Nix

NixOps

: NixOS cloud deployment tool

Disnix

: Distributed service deployment toolset

::: notes

Hydra

: Can be used to produce a binary cache. Because Nix is deterministic, it is
  like deploying automated Debian repository. No more need to compile Chromium
  on each individual developer machine.

NixOps

: Like Amazon EC2

Disnix

: More like Chef / Puppet for multiple hosts

:::

# The Nix language

## Nix---overview

- Source based
- Functional
	- A package is a function that returns instructions on how to build a path
	- Each output is in its own directory forever  
		`/nix/store/<hash>-<name>/...`
	- You can have multiple versions of the same package
- Binary caches
- Dynamically typed
- Lazy

::: notes

- Based on the ML family

- A package is a function that depends on its dependencies, compile time
  options, etc.

- Most of the time, "how to build a path" implies building the package, and
  then installing into that path

- The hash is the sha256 of the configuration of the package, meaning the result
of the "package function".

- A package which has the same hash does **not** need to be recompiled

- When you have multiple versions of the same package, they are under different
  store paths, and it can mean
	- different upstream version
	- different compilation options
	- different applied patches
	- different anything that would make the files in the output path different

**TODO**: have a section to show off how to *use* different versions

:::

## Nix---Process

- Use the Nix language to write derivations

  Derivation
  : Data structure that describes how to create an output path (file / directory)

- The derivation is compiled into a `.drv` file.
- Realising a derivation creates the output path
- The closure of an output path is the path and all its dependencies

::: notes

- Most of the time the output path is a directory which contains an FHS-like
  structure

- You can think of the `.drv` file as the result of the evaluation of your
  `.nix` files

- In simpler terms, because a package is a function, the `.drv` is the result
  of that function

:::

## Nix---Example output paths

```
/nix/store/8is5yfpd095i8pcg71pb9wxv6y6d4gfv-openssh-7.9p1
├── bin
│   ├── ssh
│   └── ...
├── etc
│   └── ssh
│       ├── ssh_config
│       └── ...
└── share
    └── man
        └── ...
/nix/store/chdjidjcmjs610024chncbin4bx211f2-asound.conf
/nix/store/486r3d12gc042yric302jg14in7j3jwm-i3.conf
```

## Nix---Language (Types)

```nix
{
  int = 1;
  boolean = true;
  string = "hello ${world}!";
  multilineString = ''
    hello
    initial indentation is removed!
  '';
  "attribute set" = { a = 1; b = 2; };
  list = [ 1 2 "hello" ];
  function = a: builtins.toString a;
  "function w/ named parameters" = { a, b, c ? "default"}: a;
}
```

::: notes

- There's also the "derivation", which is his own type.

- Function are just another type, they have a name when assigned to a variable

- Functions only take one parameter. To have more than one parameter, you write
a function that returns a function ("currying"), or use named parameters.

:::

## Nix---Language (Control Flow)


:::::: {.columns}
::: {.column width="60%"}

```nix
let
  a = 1;
  b = a + 1;
  c = var: "hello ${var}!";
in
  {
    d = if a == 1 then 2 else 3;
    e = c "world";
  }
```

:::
::: {.column width="40%"}

Gives:

```nix
{
  d = 2;
  e = "hello world!";
}
```

:::
::::::

::: notes

- This is a functional language, so every expression **must** return a value:
  a `let` returns a value, an `if` returns a value so it must have an `else`
  clause, etc.

- Implies that every time you can input a value, you can input a control flow
  expression

- Functions do not need parentheses nor commas
	- You can wrap everything around parentheses to force the order
	- It kind of is like Lisp languages but the parentheses are optional

:::

## Nix---Language (Control Flow continued)


:::::: {.columns}
::: {.column witdh="60%"}

```nix
let
  a = 1;
  b = a + 1;
  c = { d = 42; inherit b; };
in
  rec {
    inherit (c) b;
    e = with c; d + 3;
    f = e + 1;
  }
```

:::
::: {.column witdh="40%"}

Gives:

```nix
{
  b = 2;
  e = 45;
  f = 46;
}
```

:::
::::::

::: notes

- If we want to do it almost like the Nix interpreter, we start by the end, and
  look for what we want, as needed.

:::

## Puzzle

What does that do?

```nix
rec {
  a = {
    inherit a;
  };
}
```

::: notes

- Because the language is lazy, the question we have to ask is "What do we want
  from that attribute set"

:::

# How 2 perfect packaging with Nixpkgs

## An example Nixpkgs derivation

```nix
{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "hello-${version}";
  version = "2.10";

  src = fetchurl {
    url = "mirror://gnu/hello/${name}.tar.gz";
    sha256 = "0ssi1wpaf7plaswqqjwigppsg5fyh99vdlb9kzl7c9lng89ndq1i";
  };

  doCheck = true;
```

::: notes

- `stdenv` (standard environment) is a collection of packages: contains
  a C compiler, autotools, make, etc.
- `stdenv` also contains the function `mkDerivation` which automates a lot of
  package building
- In this example, the package is build using the standard `./configure; make;
  make install` and in this case, also `make test`
- You **have** to specify the `sha256` in the `fetchurl` function to make the
  network access deterministic.
  - It would invalidate a lot of Nix's assumptions if the upstream mirror
    changed the tarball

:::

---

```nix
  meta = with stdenv.lib; {
    description = "A program that produces a familiar, friendly greeting";
    longDescription = ''
      GNU Hello is a program that prints "Hello, world!" when you run it.
      It is fully customizable.
    '';
    homepage = "https://www.gnu.org/software/hello/manual/";
    license = licenses.gpl3Plus;
    maintainers = [ maintainers.eelco ];
    platforms = platforms.all;
  };
}
```

## Other examples {.shrink}


:::::: {.columns}
::: {.column}

```nix
{ stdenv, meson, ninja, pkgconfig
, qtbase, qtconnectivity }:

stdenv.mkDerivation rec {
  pname = "setup-poc";
  version = "0.1.0";
  nativeBuildInputs =
    [ meson ninja pkgconfig ];
  buildInputs =
    [ qtbase qtconnectivity ];
  mesonBuildType = "debug";
  src = ./.;
}
```

:::
::: {.column}

```nix
derive2 {
  name = "ggplot2";
  version = "3.2.0";
  sha256 = "1cvk9pw...";
  depends = [ digest gtable lazyeval
    MASS mgcv reshape2 rlang
    scales tibble viridisLite
    withr ];
};
```

:::
::::::

::: notes

- In the meson derivation, you don't need to specify a sha256 sum for the
  source: because it is local, Nix will integrate recursively the local files
  into the derivation's final hash.
	- This means: if a file changes, the hash changes, and it is another
	  package, in another path in the store
	- This also means: if a file changes, Nix will know that it has to
	  recompile this package. And because this package is passed as an argument
	  to other packages, it will also recompile every packages that depends on
	  it.

- **TODO**: Explain setup-hooks, and not only for build managers


:::

## How do you call the function

default.nix:

```nix
let
  pkgs = import <nixpkgs> {};
in
  pkgs.callPackage ./derivation.nix {}
```

We run:

```bash
nix build --file default.nix
```

::: notes

- Most of the time we use a function with default parameters, but this is for
  simplicity's sake
- `callPackage` will pass the dependencies as arguments to the derivation
  function
- `--file default.nix` is the default

:::

---

If we have derivation.nix:

```nix
{ writeShellScriptBin }:

writeShellScriptBin "myScript" "echo 'Hello, World!'"
```

We get as output path:

```
./result/
└── bin
    └── myScript
```

```
$ ./result/bin/myScript
Hello, World!
```

::: notes

- `writeShellScriptBin` is a commodity function, called a "trivial builder"


:::

---

```
$ ls -l result
result -> /nix/store/a7db5d4v5b2pxppl8drb30ljx9z0kwg0-myScript
```

. . .

`./result/bin/myScript` is:

```bash
#!/nix/store/cinw572b38aln37glr0zb8lxwrgaffl4-bash-4.4-p23/bin/bash
echo 'Hello, World!'
```

::: notes

- Everything needed by Nix or produced by Nix must be in the store
- Prevents contamination from the environment
- Build is in a chroot, with stripped env

---

- This derivation depends on a specific version of Bash (because every final
  dependency is specific)
- In Nix's terms, this specific Bash is in the closure of the "myScript"
  derivation's output path

:::

## Overlays

TODO

## Using different versions of the same package---Generic

```bash
#! /nix/store/...-bash-4.4-p23/bin/bash -e
export PATH='/nix/store/...-python-2.7.16/bin:
  /nix/store/...-glxinfo-8.4.0/bin:
  /nix/store/...-xdpyinfo-1.3.2/bin'${PATH:+':'}$PATH
export LD_LIBRARY_PATH='/nix/store/...-curl-7.64.0/lib:
  /nix/store/...-systemd-239.20190219-lib/lib:
  /nix/store/...-libmad-0.15.1b/lib:
  /nix/store/...-libvdpau-1.1.1/lib:
  ...'${LD_LIBRARY_PATH:+':'}$LD_LIBRARY_PATH
exec -a "$0" "/nix/store/...-kodi-18.1/bin/.kodi-wrapped" \
  "${extraFlagsArray[@]}" "$@"
```

::: notes

- This is actually called by another wrapper who tells Kodi where to find its
  data

:::

## Using different versions of the same package---ELF

```
$ readelf -d coreutils
...
Bibliothèque partagée: [librt.so.1]
Bibliothèque partagée: [libpthread.so.0]
Bibliothèque partagée: [libacl.so.1]
...
Bibliothèque runpath:[
  /nix/store/...-acl-2.2.53/lib:
  /nix/store/...-attr-2.4.48/lib:
  /nix/store/...-openssl-1.0.2t/lib:
  /nix/store/...-glibc-2.27/lib
]
...
```

## Using different versions of the same package---Python

```python
# imports...
sys.argv[0] = '/nix/store/...-carla-2.0.0/share/carla/carla'
functools.reduce(
  lambda k, p: site.addsitedir(p, k),
  [
    '/nix/store/...-python3.7-rdflib-4.2.2/lib/python3.7/site-packages',
    '/nix/store/...-python3.7-isodate-0.6.0/lib/python3.7/site-packages',
    '/nix/store/...-python3.7-six-1.12.0/lib/python3.7/site-packages',
    # ...
  ],
  site._init_pathinfo())
# ...
```

::: notes

- Because these paths are in the closure of the app, they are guaranteed by Nix
  to be there

:::

# NixOS

## How do you make a Linux distribution out of that?

- A distribution is a bunch of files
- In the end, the Nix package manager creates files
- Let's use Nix to create *every* (non user data) file

## Adding yourself to the environment---Symbolic links

```
$ ls -l /etc/static/ssh/ssh_config
/etc/static/ssh/ssh_config -> /nix/store/...-etc-ssh_config
```

---

```
$ systemctl cat sshd.service

# /nix/store/...-unit-sshd.service/sshd.service
# ...
[Service]
Environment="LD_LIBRARY_PATH=..."
Environment="PATH=..."

ExecStart=/nix/store/...-openssh-7.9p1/bin/sshd -f /etc/ssh/sshd_config
ExecStartPre=/nix/store/...-unit-script-sshd-pre-start
KillMode=process
Restart=always
Type=simple
```

::: notes

- The service file is in the nix store, especially in its own path!
- All linked into `/etc/systemd` so systemd can find them
- The maintainers could have put a nix store path for the sshd_config
	- The decision was made for sysadmins to be able to quick look their config
	  (`nixpkgs/pull/41744`)
- The pre start script generates host key if non-existent


:::

## Adding yourself to the environment---Environment variables

```
$ echo $PATH
/home/minijackson/bin:
/run/wrappers/bin:
/home/minijackson/.nix-profile/bin:
/etc/profiles/per-user/minijackson/bin:
/nix/var/nix/profiles/default/bin:
/run/current-system/sw/bin
```

::: notes

- Inside these dirs are symbolic links
- Environment variables with hardcoded nix store paths are quite rare in the
  user environment
	- When possible, we usually do this in the packaging


:::

## Adding yourself to the environment---Tool specific

Fontconfig
:  - Adds individual font paths into an XML file
 - Links the XML file into `/etc/fonts/fonts.conf`

Networking
:  - UDev rules
 - Systemd oneshot services
 - In the end are all linked in the environment (`/etc/{systemd,udev}`)

::: notes

- It's pretty hard to find something that can't be inserted into the user
  environment via symbolic links or env variables.
- Usually very specific cases, or badly programmed tools


:::

## How we do it

Introducing: the module system!

. . .

```nix
{ ... }:
{
  services.openssh.enable = true;
}
```

::: notes

- We talked about how it is possible for NixOS to do it, now we talk about how
  us devs write the code

- We want a machine with an SSH server
- *describe what we would do in a conventional distribution, or embedded build
  system*

---

- Will add the `sshd` user
- Will create a systemd service file, linked into `/etc`, which has the
  "openssh" package in its closure.
- Will add a default `sshd_config`
- Will add a PreStart script that generates the host key if non-existent
- Allow the 22 tcp port in the firewall (special ssh case)
- sshd PAM module
- Note: this configuration alone is two lines away from compiling:


:::

## Being pedantic

```nix
{ ... }:
{
  fileSystems."/".fsType = "tmpfs";
  boot.loader.grub.enable = false;
  services.openssh.enable = true;
}
```

## Customizing the SSH server config

```nix
{ ... }:
{
  services.openssh = {
    enable = true;
    allowSFTP = false;
    # Violates the privacy of users
    logLevel = "DEBUG";
    extraConfig = ''
      # Extra verbatim contents of sshd_config
    '';
  }
}
```

::: notes

- Compared to the previous example, this on only changes the final
  `sshd_config` file


:::

## Customizing the SSH server config

```nix
{ ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = false;
    startWhenNeeded = true;
    listenAddresses = [
      { addr = "192.168.3.1"; port = 22; }
      { addr = "0.0.0.0"; port = 64022; }
    ];
  }
}
```

::: notes

- Start when needed will add a systemd socket that will only listen to the
  content of `listenAddresses` (if defined).
- But the content of `listenAddresses` is also added to the `sshd_config`.
- This gives us a higher level description of what we want in our system.
- They also give us the means to describe our higher level components, should
  nixpkgs not have the appropriate module.


:::

## More examples

```nix
{ ... }:
{
  systemd.services.myService = {
    description = "My really awesome service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${myPackage}/bin/myExec";
      DynamicUser = true;
    };
  };
}
```

::: notes

- In the previous example, the openssh module created a systemd service for us.
  Now we create or own systemd service.
- In fact the openssh module will (in part) "modify" the systemd module.
- And in turn, the systemd module will "modify" the module that sets up `/etc`.
- There is no defined "order" / "hierarchy" of modules, the laziness of the Nix
  language permits that (this can theoretically lead to infinite loops).
- So really, the Nix language does this in reverse (activation script -> `/etc`
  -> systemd -> openssh -> maybe higher level concepts)


:::

## Moaaar examples

```nix
{ ... }:
{
  containers = {
    myContainer = {
      config = { ... }: { services.postgresql.enable = true; };
    };
    myOtherContainer = {
      config = { ... }: { services.nginx.enable = true; };
      forwardPorts = [
        { containerPort = 80; hostPort = 8080; protocol = "tcp"; }
      ];
    };
  };
}
```

## Composition

```nix
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./usecases/ssh-server.nix
    ./usecases/web-interface.nix
  ];
}
```

## "Overridability"---Provided

```nix
{ ... }:
{
  hardware.bluetooth = {
    enable = true;
    package = myBluezFork;
  };
}
```

## "Overridability"---Forced

```nix
{ lib, ... }:
{
  services.unbound.enable = true;
  # These tricks are done by "professionals".
  # Don't try this at home
  systemd.services.unbound.serviceConfig.ProtectSystem =
    lib.mkForce false;
}
```

## "Overridability"---Commando mode

```nix
{ ... }:
{
  nixpkgs.overlays = [ (self: super: {
    bluez = myBluezFork;
  } ) ];
}
```

Otherwise, you can just copy and edit the official module file.

::: notes

- Changing things in overlays also changes packages dependencies, which in the
  case of Bluez, there are quite a lot.

:::

## Assertions

```
Failed assertions:
- services.xserver.xkbOptions = "eurosign:e" is useless on fr/ch
  layouts and plays badly with bépo
```

# The embedded world

## Proper project structure

<https://github.com/illegalprime/nixos-on-arm>

```nix
{ ... }:
{
  imports = [
    <machine>
    <image>
  ];
}
```

```
$ nix build -f default.nix \
    -I machine=./machines/MY_BOARD \
    -I image=./images/MY_CONFIGURATION
```

## TODO

- [x] Use good Markdown / Beamer template
- [ ] Pinning repo version
- [x] How to use different versions
- [ ] Modules can call other modules (and that's what they do **all** the time)
- [ ] How to build an image
- [ ] Add some images to temporise the talk
- [ ] Talk about service tests!!!
	- [ ] Single-node
	- [ ] Multi-node
- [ ] Add derivation example with compilation options
- [ ] Add intro? about problems that I had in Buildroot (non-determinism, no
  auto-recompile)
- [ ] Talk about nix-shell
- [ ] Talk about nix-shell scripts
- [ ] Talk about nixops
- [ ] Talk about choosing generation at boot
- [ ] Have a functional programming intro
- [ ] You **don't** need to run NixOS to develop with Nix
- [ ] https://r13y.com/
- [ ] Drawbacks
	- [ ] Harder to compile anything, especially packages with bad build systems
	- [ ] If one package doesn't compile, harder to compile the system, since
	  it's a dependency of the system closure
	- [ ] You need deeper understanding of the ecosystem to package random
	  programs
	- [ ] Sometimes need to patch software to bypass hardcoded paths (e.g.
	  locale archive)
	- [ ] For now, only world readable store, makes it kinda harder for
	  passwords and other secrets
	- Documentation / developer experience is sub-optimal
- [ ] A burnable image is just a file that depends on every package of your
  system
	- [ ] instead of depending manually on each package, we depend on the
	  top-level system closure (output and all dependencies)

## The End {.standout}

That's all folks!

---

Questions?

Slide sources
 ~ <https://github.com/minijackson/nixos-embedded-slides/>

:::::: {.columns}
::: {.column width="40%"}

- <https://nixos.org/>
- <https://nixos.wiki/>

:::
::: {.column width="60%"}

- <https://nixos.org/nix/manual/>
- <https://nixos.org/nixpkgs/manual/>
- <https://nixos.org/nixos/manual/>

:::
::::::

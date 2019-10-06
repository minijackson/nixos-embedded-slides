---
title: NixOS for Embedded systems
author: Rémi Nicole
date: 2019-10-09
slide-level: 2
aspectratio: 169

theme: metropolis
colortheme: owl
beameroption: "show notes on second screen=right"

toc: true
highlightstyle: breezedark
lang: en-US


header-includes: |
  ```{=latex}
  \usepackage{csquotes}
  \usepackage{pgfpages}
  \usepackage{dirtree}
  %\usepackage{beamerarticle}

  \setbeamercolor{section in toc}{
    use=normal text,
    fg=normal text.fg
  }
  \setbeamercolor{subsection in toc}{
    use=normal text,
    fg=normal text.fg
  }

  \usepackage{fvextra}

  \usepackage[outputdir=build]{minted}
  \usemintedstyle{dracula}
  \definecolor{mybg}{rgb}{0.207843, 0.219608, 0.27451}
  \setminted{bgcolor=mybg,tabsize=4,breaklines}

  \setmonofont{Fira Code}[ItalicFont={Latin Modern Mono 10 Italic}]
  ```
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
- This also is a "bottom-up" talk, which means:
	- More technical, but
	- Should lead to better understanding
	- How, and why it works
	- Maybe apply some of these concepts in your daily work (using, Buildroot,
	  Yocto, etc.)


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

  Derivation:
  : Data structure that describes how to create an output path (file / directory)

- The derivation is compiled into a `.drv` file (evaluation).
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

```{=latex}
\dirtree{%
	.1 /nix/store/8is5yfpd095i8pcg71pb9wxv6y6d4gfv-openssh-7.9p1.
	.2 bin.
	.3 ssh.
	.3 \ldots.
	.2 etc.
	.3 ssh.
	.4 ssh\_config.
	.5 \ldots.
	.2 share.
	.3 man.
	.4 \ldots.
}
```

```
/nix/store/chdjidjcmjs610024chncbin4bx211f2-asound.conf
/nix/store/486r3d12gc042yric302jg14in7j3jwm-i3.conf
```

## Nix---Language (Types){.fragile .shrink}

```{=latex}
\begin{minted}{nix}
{
  int = 1;
  boolean = true;
  string = "hello ${world}!";
  multilineString = ''
    hello
    initial indentation is removed!
  '';
  "attribute set" = { a = 1; b = 2; };
  a.b.c = 1; # same as a = { b = { c = 1; }; };
  list = [ 1 2 "hello" ];
  function = a: toString a;
  "function w/ named parameters" = { a, b, c ? "default"}: a;
}
\end{minted}
```

::: notes

- There's also the "derivation", which is his own type.

- Function are just another type, they have a name when assigned to a variable

- Functions only take one parameter. To have more than one parameter, you write
a function that returns a function ("currying"), or use named parameters.

:::

## Nix---Language (Control Flow){.fragile}


:::::: {.columns}
::: {.column width="60%"}

```{=latex}
\begin{minted}{nix}
let
  a = 1;
  b = a + 1;
  c = var: "hello ${var}!";
in
  {
    d = if a == 1 then 2 else 3;
    e = c "world";
  }
\end{minted}
```

:::
::: {.column width="40%"}

Gives:

```{=latex}
\begin{minted}{nix}
{
  d = 2;
  e = "hello world!";
}
\end{minted}
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

## Nix---Language (Control Flow continued){.fragile}


:::::: {.columns}
::: {.column witdh="60%"}

```{=latex}
\begin{minted}{nix}
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
\end{minted}
```

:::
::: {.column witdh="40%"}

Gives:

```{=latex}
\begin{minted}{nix}
{
  b = 2;
  e = 45;
  f = 46;
}
\end{minted}
```

:::
::::::

::: notes

- If we want to do it almost like the Nix interpreter, we start by the end, and
  look for what we want, as needed.

:::

## Puzzle{.fragile}

What does that do?

```{=latex}
\begin{minted}{nix}
rec {
  a = {
    inherit a;
  };
}
\end{minted}
```

::: notes

- Because the language is lazy, the question we have to ask is "What do we want
  from that attribute set"

:::

# How 2 perfect packaging with Nixpkgs

## An example Nixpkgs derivation{.fragile}

```{=latex}
\begin{minted}{nix}
{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "hello-${version}";
  version = "2.10";

  src = fetchurl {
    url = "mirror://gnu/hello/${name}.tar.gz";
    sha256 = "0ssi1wpaf7plaswqqjwigppsg5fyh99vdlb9kzl7c9lng89ndq1i";
  };

  doCheck = true;
\end{minted}
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

```{=latex}
\begin{minted}{nix}
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
\end{minted}
```

```
```

## Other examples{.fragile}


:::::: {.columns}
::: {.column}

```{=latex}
\begin{minted}{nix}
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
\end{minted}
```

:::
::: {.column}

```{=latex}
\begin{minted}{nix}
derive2 {
  name = "ggplot2";
  version = "3.2.0";
  sha256 = "1cvk9pw...";
  depends = [ digest gtable
    lazyeval MASS mgcv reshape2
    rlang scales tibble
    viridisLite withr ];
};
\end{minted}
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

## Examples with non dependencies parameters{.fragile}

```{=latex}
\begin{minted}{nix}
{ stdenv, cmake, ninja, fetchFromGitHub
, static ? false }:

stdenv.mkDerivation rec {
  pname = "gtest";
  version = "1.8.1";
  outputs = [ "out" "dev" ];
  nativeBuildInputs = [ cmake ninja ];

  cmakeFlags = stdenv.lib.optional (!static) "-DBUILD_SHARED_LIBS=ON";
  # src = ...; patches = ...; meta = ...;
}
\end{minted}
```

---

```{=latex}
\begin{minted}{nix}
{ stdenv, fetchurl, perl, libiconv, zlib, popt
, enableACLs ? !(stdenv.isDarwin || stdenv.isSunOS || stdenv.isFreeBSD)
, acl ? null, enableCopyDevicesPatch ? false }:

assert enableACLs -> acl != null;
with stdenv.lib;
stdenv.mkDerivation rec {
  # pname = "rsync"; ...
  srcs = [mainSrc] ++ optional enableCopyDevicesPatch patchesSrc;
  patches = optional enableCopyDevicesPatch "./patches/copy-devices.diff";

  buildInputs = [libiconv zlib popt] ++ optional enableACLs acl;
}
\end{minted}
```

```
```

::: notes

- Some usual examples include:
	- Build static / shared versions
	- Build documentation (usually in its own output)
	- Enable / Disable compilation features (helps reduce dependencies)

:::

## How do you call the function

default.nix:

```{=latex}
\begin{minted}{nix}
let
  pkgs = import <nixpkgs> {};
in
  pkgs.callPackage ./derivation.nix {}
\end{minted}
```

- We run:

```{=latex}
\begin{minted}{console}
roger@os $ nix build --file default.nix
\end{minted}
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

```{=latex}
\begin{minted}{nix}
{ writeShellScriptBin }:

writeShellScriptBin "myScript" "echo 'Hello, World!'"
\end{minted}
```

We get as output path:

```{=latex}
\dirtree{%
	.1 ./result/.
	.2 bin.
	.3 myScript.
}
```

```{=latex}
\begin{minted}{console}
slartibartfast@magrathea $ ./result/bin/myScript
Hello, World!
\end{minted}
```

::: notes

- `writeShellScriptBin` is a commodity function, called a "trivial builder"


:::

---

```{=latex}
\begin{minted}{console}
slartibartfast@magrathea $ ls -l result
result -> /nix/store/a7db5d4v5b2pxppl8drb30ljx9z0kwg0-myScript
\end{minted}
```

`./result/bin/myScript` is:

```{=latex}
\begin{minted}{bash}
#!/nix/store/cinw572b38aln37glr0zb8lxwrgaffl4-bash-4.4-p23/bin/bash
echo 'Hello, World!'
\end{minted}
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

## Overlays{.fragile}

```{=latex}
\begin{minted}{nix}
let
  pkgs = import <nixpkgs> {
    overlays = [
      (self: super: {
        myAlias = super.pandoc;
        inherit (super.llvmPackages_7) clang libclang llvm;
        myPackage = self.callPackage ./myProject/default.nix { };
      } )
    ];
  };
in
  pkgs.myPackage
\end{minted}
```

::: notes

- Because the `callPackage` is from `self`, `myPackage` is able to use
  `myAlias` and if it uses `clang`, `libclang`, or `llvm`, it will be from
  version 7.
- Also, every package that doesn't explicitly specify its `llvm` version will
  now use version 7.
- This might not be what we want.


:::

## Overriding parameters{.fragile}

```{=latex}
\begin{minted}{nix}
self: super: {
  gtest = super.gtest.override { static = true; };
  myRsync = super.rsync.override { enableACLs = false; };

  myGimp = super.gimp-with-plugins.override {
    plugins = [ super.gimpPlugins.gmic ];
  };

  rsnapshot = super.rsnapshot.override { rsync = self.myRsync; };
}
\end{minted}
```

## Overriding attributes{.fragile}

```{=latex}
\begin{minted}{nix}
self: super: {
  myRedshift = super.redshift.overrideAttrs (oldAttrs: {
    src = self.fetchFromGitHub {
      owner = "minus7";
      repo = "redshift";
      rev = "...";
      sha256 = "...";
    };
  });
}
\end{minted}
```

::: notes

- Useful for ie. adding patches without having to copy the definition.


:::

## Using different versions of the same package---Generic{.fragile}

. . .

```{=latex}
\begin{minted}{bash}
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
\end{minted}
```

::: notes

- *Strategic pause*
- This is actually called by another wrapper who tells Kodi where to find its
  data.
- Everything you see here is automated, writing derivations is much much less
  complicated.


:::

## Using different versions of the same package---ELF{.fragile}

```{=latex}
\begin{minted}{console}
PinkiePie@Equestria $ readelf -d coreutils
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
\end{minted}
```

## Using different versions of the same package---Python{.fragile}

```{=latex}
\begin{minted}{python}
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
\end{minted}
```

::: notes

- Because these paths are in the closure of the app, they are guaranteed by Nix
  to be there

:::

## Shelling out{.fragile}

```{=latex}
\begin{minted}{console}
roger@os $ nix-shell '<nixpkgs>' -A openssh
roger@os (nix-shell) $ echo $src
/nix/store/...-openssh-7.9p1.tar.gz
roger@os (nix-shell) $ pkg-config --cflags openssl
-I/nix/store/...-openssl-1.0.2t-dev/include
roger@os (nix-shell) $ unpackPhase
...
roger@os (nix-shell) $ configurePhase
...
\end{minted}
```

::: notes

- pkg-config is here because it's in the native build inputs
- There is also the concept of nix-shell scripts, which declare their
  dependencies, and Nix will download and provide the dependencies before
  running the script.


:::

# NixOS

## How do you make a Linux distribution out of that?

- A distribution is a bunch of files

- In the end, the Nix package manager creates files

- Let's use Nix to create *every* (non user data) file

## Adding yourself to the environment---Symbolic links{.fragile}

```{=latex}
\begin{minted}{console}
roger@os $ ls -l /etc/static/ssh/ssh_config
/etc/static/ssh/ssh_config -> /nix/store/...-etc-ssh_config
\end{minted}
```

---

```{=latex}
\begin{minted}{ini}
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
\end{minted}
```

```
```

::: notes

- The service file is in the nix store, especially in its own path!
- All linked into `/etc/systemd` so systemd can find them
- The maintainers could have put a nix store path for the sshd_config
	- The decision was made for sysadmins to be able to quick look their config
	  (`nixpkgs/pull/41744`)
- The pre start script generates host key if non-existent


:::

## Adding yourself to the environment---Environment variables{.fragile}

```{=latex}
\begin{minted}{console}
roger@os $ echo $PATH
/home/minijackson/bin:
/run/wrappers/bin:
/home/minijackson/.nix-profile/bin:
/etc/profiles/per-user/minijackson/bin:
/nix/var/nix/profiles/default/bin:
/run/current-system/sw/bin
\end{minted}
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

## How we do it{.fragile}

Introducing: the module system!

. . .

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  services.openssh.enable = true;
}
\end{minted}
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


:::

## Customizing the SSH server config{.fragile}

```{=latex}
\begin{minted}{nix}
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
\end{minted}
```

::: notes

- Compared to the previous example, this on only changes the final
  `sshd_config` file


:::

## Customizing the SSH server config

```{=latex}
\begin{minted}{nix}
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
\end{minted}
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

```{=latex}
\begin{minted}{nix}
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
\end{minted}
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

## Moaaar examples{.fragile}

```{=latex}
\begin{minted}{nix}
{ ... }: {
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
\end{minted}
```

## Composition{.fragile}

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./usecases/ssh-server.nix
    ./usecases/web-interface.nix
  ];
}
\end{minted}
```

## "Overridability"---Provided{.fragile}

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  hardware.bluetooth = {
    enable = true;
    package = myBluezFork;
  };
}
\end{minted}
```

## "Overridability"---Forced{.fragile}

```{=latex}
\begin{minted}{nix}
{ lib, ... }:
{
  services.unbound.enable = true;
  # These tricks are done by "professionals".
  # Don't try this at home
  systemd.services.unbound.serviceConfig.ProtectSystem =
    lib.mkForce false;
}
\end{minted}
```

## "Overridability"---Commando mode{.fragile}

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  nixpkgs.overlays = [ (self: super: {
    bluez = myBluezFork;
  } ) ];
}
\end{minted}
```

Otherwise, you can just copy and edit the official module file.

::: notes

- Changing things in overlays also changes packages dependencies, which in the
  case of Bluez, there are quite a lot.

:::

## Defining our own modules{.fragile}

The true module structure:

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  imports = [ /* ... */ ];
  options = { /* ... */ };
  config = { /* ... */ };
}
\end{minted}
```

## Defining our own modules---API{.fragile}

```{=latex}
\begin{minted}[lastline=10]{nix}
{ lib, pkgs, config, ... }:
with lib;
{
  options.services.myService = {
    enable = mkEnableOption "myService, awesomeness incarnated";

    port = mkOption {
      type = types.port; # = ints.u16
      default = 1337
      description = "The listen port for this service";
    };
  };
}
\end{minted}
```

::: notes

- Whether to enable "myService, awesomeness incarnated"


:::

## Defining our own modules---API{.fragile}

```{=latex}
\begin{minted}[firstline=4,lastline=16]{nix}
{ lib, pkgs, ... }:
{
  options.services.myService = with lib; {
    package = mkOption {
      type = types.package;
      default = pkgs.myPackage;
      defaultText = "pkgs.myPackage";
      description = "The package to use for this service";
    };

    user = mkOption {
      type = with types; nullOr string;
      default = null;
      description = "The user this service will run as.";
    };
  }; # options.services.myService
};
\end{minted}
```

## Defining our own modules---Implementation{.fragile}

```{=latex}
\begin{minted}[firstline=3,lastline=10]{nix}
{ lib, pkgs, ... }:
{
  config = let
    cfg = config.services.myService;
  in
    mkIf cfg.enable {
      systemd.services.myService = {
        description = "My awesome service";
        wantedBy = [ "multi-user.target" ];

      };
    };
}
\end{minted}
```

## Defining our own modules---Implementation{.fragile}

```{=latex}
\begin{minted}[firstline=5,lastline=13]{nix}
{ lib, pkgs, ... }:
{
    config = mkIf cfg.enable {
      systemd.services.myService = {
        serviceConfig = {
          ExecStart =
            "${cfg.package}/bin/myserviced --port ${toString cfg.port}"
        } // (if isNull cfg.user then {
          DynamicUser = true;
        } else {
          User = cfg.user;
        });
      }; # systemd.services.myService
    };
}
\end{minted}
```

::: notes

- Sorry if the formatting is horrible, it had to fit in one slide.


:::

## Defining our own modules---Implementation{.fragile}

```{=latex}
\begin{minted}[firstline=4,lastline=13]{nix}
{ lib, pkgs, ... }:
{
    config = mkIf cfg.enable {
      users.users = mkIf (!isNull cfg.user) {
        "${cfg.user}".uid = 42; # < don't do that
      };
    }; # config
} # The end!
\end{minted}
```

::: notes

- **Ask me a question about the UID situation at the end of the talk**
- We can't go around assigning random UIDs because:
	- It's not deterministic
	- If done deterministically (ie. not randomly, but by assigning the first
	  free UID), a UID can change between rebuilds, and can  introduces file
	  permission issues.
- So we have a list of fixed UIDs, so that each service has their own UIDs,
  forever, for everyone
- The list is quite big, which is why `DynamicUser`s are so important for NixOS


:::

## Assertions{.fragile}

```{=latex}
\begin{minted}{md}
Failed assertions:
- The ‘fileSystems’ option does not specify your root file system.
- You must set the option ‘boot.loader.grub.devices’ or
  'boot.loader.grub.mirroredBoots' to make the system bootable.
\end{minted}
```

## More Assertions

- *Synaptics and libinput are incompatible, you cannot enable both* (in
  `services.xserver`).

- *CONFIG_ZRAM is not built as a module!* (in `zramSwap`)

- *Yubikey and GPG Card may not be used at the same time.* (in
  `boot.initrd.luks`)

- *Trusted GRUB does not have EFI support* (in `boot.loader.grub`)

## Assertion implementations{.fragile}

```{=latex}
\begin{minted}{nix}
# in module configuration
{
  assertions = [
    { assertion = any (fs: fs.mountPoint == "/") fileSystems;
      message = "The ‘fileSystems’ option does not specify your root file system.";
    }
  ];
}
\end{minted}
```


::: notes

Yes, these assertions are also a NixOS module!


:::

## Module tests{.fragile}

```{=latex}
\begin{minted}{nix}
import ./make-test.nix ({ ... }: {
  name = "myService";
  machine = { ... }: {
    services.myService.enable = true;
  };

  testScript = ''
    $machine->waitForUnit('myService.service');
    $machine->waitForOpenPort('1337');
    $machine->succeed("curl --fail http://localhost:1337/");
  '';
})
\end{minted}
```

::: notes

- Will create a VM with the given config, and run the Perl script on that


:::

## Module tests, The Empire Strikes Back{.fragile}

```{=latex}
\begin{minted}{nix}
import ./make-test.nix ({ pkgs, ... } : {
  name = "kernel-latest";
  machine = { pkgs, ... }: {
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };

  testScript = ''
    $machine->succeed("uname -s | grep 'Linux'");
    $machine->succeed("uname -a | grep '${pkgs.linuxPackages_latest.kernel.version}'");
  '';
})
\end{minted}
```

## Module tests, Return of the Jedi{.fragile}

```{=latex}
\begin{minted}[lastline=13]{nix}
import ./make-test.nix ({ pkgs, ... } : with pkgs.lib; {
  name = "Bridge";
  nodes.client1 = { pkgs, ... }: {
    virtualisation.vlans = [ 1 ];
    networking = {
      useDHCP = false;
      interfaces.eth1.ipv4.addresses = [ {
        address = "192.168.1.2/24"; prefixLength = 24
      } ];
    };
  };
  nodes.client2 = { /* same but in vlan 2 @ 192.168.1.3 */ };
  nodes.router = { /* bridges the vlans 1 and 2 */ };
})
\end{minted}
```

## Module tests, The Phantom Menace{.fragile}

Test script:

```{=latex}
\begin{minted}{perl}
startAll;
# Wait for networking to come up
$client1->waitForUnit("network.target");
$client2->waitForUnit("network.target");
$router->waitForUnit("network.target");
# Test bridging
$client1->waitUntilSucceeds("ping -c 1 192.168.1.1");
$client1->waitUntilSucceeds("ping -c 1 192.168.1.2");
$client1->waitUntilSucceeds("ping -c 1 192.168.1.3");
# Same with client2 and router
\end{minted}
```

::: notes

- There are even the possibilities of:
	- Taking a screenshot
	- Running OCR on screenshot

:::

# The embedded world

## Proper project structure{.fragile}

<https://github.com/illegalprime/nixos-on-arm>

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  imports = [
    <machine>
    <image>
  ];
}
\end{minted}
```

```{=latex}
\begin{minted}{console}
roger@os $ nix build -f default.nix \
    -I machine=./machines/MY_BOARD \
    -I image=./images/MY_CONFIGURATION
\end{minted}
```

## Building an iso image{.fragile}

```{=latex}
\begin{minted}{nix}
{ ... }:
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/sd-image.nix>
  ];

  # ---8<---
}
\end{minted}
```

```{=latex}
\begin{minted}{console}
roger@os $ nix build -f default.nix config.system.build.sdImage
\end{minted}
```

::: notes

- Yes, it's a module again!
- In the end an image is just a file that depends on your system
- The sd-image module just uses the result of the `toplevel` derivation


:::

## Other useful features

- Repository pinning (a.k.a. just clone `nixpkgs`)

- Cross System (**no need to be on NixOS**)
	- i686-linux / x86_64-linux
	- x86_64-darwin (MacOS)
	- *Beta*: aarch64-linux / FreeBSD

- Rollbacks

- Declarative deployments (NixOps)

::: notes

- To rollback, you can just switch to the previous configuration, either by
  manually changing the config files, or choosing a previous configuration at
  boot

:::

# Recap

## 4ever Drawbacks

### Packaging

- The language is alien
- harder (depends on the software / stack)
	- *1304 out of 1321 (98.71%) paths in the minimal installation image are
	  reproducible*[^1]
- You need deeper understanding of the ecosystem
- Sometimes need to patch software to bypass hardcoded paths (e.g. locale archive)
- No "smart" recompilation of dependents

[^1]: <https://r13y.com/>

::: notes

- Not reprodocible paths includes:
	- Python bytecode with timestamps
	- Some autotools
	- EFI stuff

:::

### NixOS

- You can't compile part of a system without changing your configuration (all
  or nothing)
- If something doesn't work, you will need to dive into the abstractions
- Non POSIX compliant


::: notes

- The final systems depends on the success of all derivations
- Non POSIX compliant means more work to make some tools work
- Another way to see it, NixOS does things so differently, and developers don't
  tend to take that into account.


:::

## Current drawbacks

- Documentation / developer experience is sub-optimal

- Maturity (especially for Embedded)

- For now, only world readable store, makes it kinda harder for passwords and
  other secrets

- Cross compilation is not well tested / integrated


::: notes

- Reading the code because the documentation isn't there yet happens way too
  much.


:::

## Un-talked Advantages

- Made out of simple building blocks
	- Makes it possible to develop tools
- Hydra
	- Safe binary cache
	- Distributed builds
- Distributed Nix store
- Very strong Haskell community for some reason :-)
- Usage as a server or workstation
- "Works for me" \rightarrow "Works for everybody"


## The End{.standout}

That's all folks!

## {.standout}

Questions?

```{=latex}
\begin{center}\rule{0.5\linewidth}{\linethickness}\end{center}
```

Slide sources:
 ~ <https://github.com/minijackson/nixos-embedded-slides/>


```{=latex}
\begin{center}\rule{0.5\linewidth}{\linethickness}\end{center}
```

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

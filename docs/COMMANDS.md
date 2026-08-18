# ARX command guide

ARX accepts pacman-compatible short forms and readable long forms. Read-only commands run without sudo; ARX requests elevation only when a transaction needs it.

## Search and inspect

```sh
arx -Q package-name
arx -Query package-name
arx search package-name
arx -Search package-name
arx -Si package-name
arx -Info package-name
```

`-Q` queries the installed/local database. `-S`/`search` searches available packages.

## Remove packages

Exact package removal:

```sh
arx -Rns package-name
arx -Remove --recursive --nosave package-name
arx remove package-name
```

The common shell pattern below is valid but unnecessary with ARX:

```sh
sudo pacman -Rns "$(pacman -Qq package-name)"
```

ARX's easier equivalent is:

```sh
arx remove --recursive --nosave package-name
```

ARX resolves the installed package directly from libalpm instead of spawning a second package-query process.

## Other useful pacman-compatible commands

```sh
arx -S package-name          # install
arx -Sync package-name      # same operation, readable form
arx -Syu                    # sync databases + full system upgrade
arx -Sync --sysupgrade      # readable equivalent
arx -R package-name         # remove
arx -Rns package-name       # remove + recursive dependency cleanup + config removal
arx -U ./package.pkg.tar.zst # install/upgrade local package
arx -Q                     # list/query installed packages
arx -Qe                    # explicitly installed packages
arx -Qs pattern            # search installed packages
arx -Qo /path/to/file      # find owning package
arx -Ql package-name      # list files owned by a package
arx -Si package-name      # repository package information
arx -Sii package-name     # extended repository information
arx -Sc                    # clean package cache
arx -Scc                   # remove all cached packages
arx -Dk                    # check dependency database consistency
arx -T package-name       # dependency test
arx -F /path/to/file      # search package file databases
```

## ARX-native conveniences

```sh
arx install package-name
arx remove package-name
arx search package-name
arx info package-name
arx outdated
arx orphans
arx mirrors
arx mirror rank
arx sync
```

Search results identify their source:

```text
PACMAN
  1  package-name   1.2.3

AUR · 4 similar packages
  2  package-name-git  1.2.3.r42
  3  package-name-bin  1.2.3
```

Numbers can be selected interactively to install a result. ARX must preserve the package source (official repository vs AUR) and exact version information throughout selection and installation.

## Privilege model

Do not run `sudo arx` for normal use:

```sh
arx -Q package-name       # no sudo
arx search firefox        # no sudo
arx -Si firefox           # no sudo
arx -S firefox            # ARX elevates only when libalpm needs it
arx -Rns firefox          # ARX elevates only when libalpm needs it
```

This keeps read-only paths fast and avoids unnecessary privilege prompts.

## Shell-command equivalents

ARX aims to make common multi-command shell recipes unnecessary. Prefer:

```sh
arx remove --recursive --nosave package-name
```

over:

```sh
arx -Rns "$(arx -Qq package-name)"
```

and:

```sh
arx query package-name
```

over:

```sh
arx -Q package-name
```

## Accuracy policy

Performance optimizations must not change package names, versions, repository/source attribution, dependency relationships, transaction plans, signature verification, or filesystem effects. ARX uses libalpm for package-management transaction semantics and treats correctness as a hard requirement.

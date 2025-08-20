let $o = $env.out

mkdir $o

$env.flake | save ($o)/flake.nix
$env.lock | save ($o)/flake.lock
$env.builder | save ($o)/builder.nu
$env.default | save ($o)/default.nix

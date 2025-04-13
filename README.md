# Flake for configuring NixOS systems

This flake defines two NixOS systems, one called `base` which is just a kinda
minimal system, and one called `aethelred` which is intended for a specific
physical machine in my office.

You can run `base` in a VM like this:

```
nix run .#nixosConfigurations.base.config.system.build.vm
```

The details of what this does seem to be configured by a set of options under
`virtualisation.*` (to access these I needed to import
`${modulesPath}/virtualisation/qemu-vm.nix`). For example, because I set
`virtualisation.forwardPorts`, you can SSH into the guest with `ssh -p 2222
localhost`.

I installed NixOS using the installer on `aethelred`. I can then rebuild it
according to the config in this Flake by running `nixos-rebuild` with the
`--target-host` option. It seems in principle like it should have been possible
to directly generate the disk image and just splat the build directly onto the
machine's disk without needing to run an installer at all, but:

- I haven't figured out how to build disk images yet (although the QEMU VM built
  above does create a QCOW2 image).
- I don't know how I'd have genetaed `aethelred-hardware-configuration.nix` -
  that was generated by the NixOS installer and then I copied it off the
  machine.

## Stuff I need to figure out

- How the hell do I get code navigation working for Nix? I think I want to
  configure something like [`nil`](https://github.com/oxalica/nil), and I want it
  to be a `devShell`, the I'll run `nix develop` and then `code .`, at least
  according to ChatGPT, if you do that then VSCode inherits the environment.
- Once I have some capability to actually read the damn code, try and stare at
  it and figure out how the hell the kernel build process works.
- Then, based on that beautiful new understanding, figure out how to build a
  minimal kernel. At the moment if I try and disable drivers I hit errors like
  this:

  ```
  ❯❯  nix build .#nixosConfigurations.base.config.system.build.vm
  warning: Git tree '/home/brendan/src/nixos-flake' is dirty
  error: builder for '/nix/store/pmp9nhivx2gl5aapb98cv33psn7ycz8y-linux-6.14-modules-shrunk.drv' failed with exit code 1;
        last 10 log lines:
        >   copying dependency: /nix/store/gl2zf0bgwcihm4kibvk0cp35qxrmf593-linux-6.14-modules/lib/modules/6.14.0/kernel/fs/overlayfs/overlay.ko
        > root module: ext2
        >   builtin dependency: ext4
        > root module: ext4
        >   builtin dependency: ext4
        > root module: ahci
        >   copying dependency: /nix/store/gl2zf0bgwcihm4kibvk0cp35qxrmf593-linux-6.14-modules/lib/modules/6.14.0/kernel/drivers/ata/libahci.ko
        >   copying dependency: /nix/store/gl2zf0bgwcihm4kibvk0cp35qxrmf593-linux-6.14-modules/lib/modules/6.14.0/kernel/drivers/ata/ahci.ko
        > root module: sata_nv
        > modprobe: FATAL: Module sata_nv not found in directory /nix/store/gl2zf0bgwcihm4kibvk0cp35qxrmf593-linux-6.14-modules/lib/modules/6.14.0
        For full logs, run 'nix log /nix/store/pmp9nhivx2gl5aapb98cv33psn7ycz8y-linux-6.14-modules-shrunk.drv'.
  error: 1 dependencies of derivation '/nix/store/qrn66wsn6y8vm8d3131s31xhqx63x50g-initrd-linux-6.14.drv' failed to build
  error: 1 dependencies of derivation '/nix/store/j5rpswhhvrdbn35bbb10a7fbawi1qi3p-nixos-system-nixos-24.11.20250410.f9ebe33.drv' failed to build
  error: 1 dependencies of derivation '/nix/store/s53wzyyavp60wf4nrp4330xly9b0frk8-nixos-vm.drv' failed to build
  ```
- Then, I also need `ccache` support. I asked about that
  [here](https://discourse.nixos.org/t/help-using-ccache-for-kernel-build/63010)
  but no answers yet.

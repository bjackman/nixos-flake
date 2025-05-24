# FALBA

This is an experimental library for managing and analysing benchmarking results.
It's vendored into my ASI benchmarking repository while I prototype it, it
doesn't really belong here.

TODO:

- Decide on the data model:
  - What about units?
  - Should facts nest?
  - How should we make facts "type safe" but also flexible?
  - How can we avoid some sort of silly implicit assumption that "facts" all
    describe a single "entity"?
  - The "instrumented" fact has a "default value", I guess this is useful...

## Type Checking with Pyright

This project uses [pyright](https://github.com/microsoft/pyright) for static type checking.

To set it up and run it:

1.  Ensure you have Python 3.8 or newer.
2.  Install the project with the development dependencies:
    ```bash
    pip install -e .[dev]
    ```
    (This command should be run from the `src/falba` directory).
3.  Run pyright:
    ```bash
    pyright
    ```
    (This command should also be run from the `src/falba` directory).

- Add pylint/pyfmt/type checker/etc
- Add some tests
# typestate-v

## Description

Proof of concept for a typestate checker for V. This is built as a part of my MSc thesis at the University of Glasgow.

Long term goal is to merge this into the V compiler itself as an additional stage before `cgen`.

## Pre-requisites

### Install V from source.

It is recommended to follow the instructions from
the [official documentation](https://github.com/vlang/v/blob/master/README.md#installing-v-from-source).

If you're on a Unix-like system, you can run the following commands to install V from source:

```bash
cd some/appropriate/path
git clone --depth=1 https://github.com/vlang/v
cd v
make
```

If on Windows, please refer to the additional instructions in the official documentation.

### Symlink the `v` binary.

Ensure that the `v` binary is in your `PATH` by symlinking it:

```bash
sudo ./v symlink
```

The process is similar on Windows. Refer to the official documentation for more details.

Test that the installation was successful by running:

```bash
v version
```

### Updating V

Once V is installed, you can update it by running:

```bash
v up
```

## Usage

Clone this repository:

```bash
cd some/appropriate/path
git clone ...
cd typestate_v
```

Run the main binary with:

```bash
v run . [path/to/case/study]
```

If you want to view the help information, run:

```bash
v run . help
```


To run the typestate checker on all enabled case studies, run:

```bash
v run . case-study
```

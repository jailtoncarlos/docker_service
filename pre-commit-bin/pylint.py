#!/usr/bin/python3
import os
import shlex
import subprocess
import sys


def get_changed_files():
    try:
        process = subprocess.Popen(  # pylint: disable=R1732:
            shlex.split("git diff --name-only"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=False,
        )
        stdout, stderr = process.communicate()
        if process.returncode != 0:
            raise Exception(stderr.decode())  # pylint: disable=W0719
    except RuntimeError as exc:
        sys.stderr.write(f"Erro durante a execução do pylint: {exc}")
        sys.exit(1)

    files = [
        line.rstrip().decode() for line in stdout.splitlines() if line.endswith(b".py")
    ]
    return files


def main():
    if "--all" in sys.argv:
        apps = "."
        if "-v" in sys.argv or "--verbose" in sys.argv:
            sys.stdout.write(">>> All files will be evaluated\n")
    else:
        files = get_changed_files()
        apps = " ".join(file for file in files if os.path.exists(file))
        if "-v" in sys.argv or "--verbose" in sys.argv:
            sys.stdout.write(">>> The following files will be evaluated:\n")
            sys.stdout.write("\n".join(files))
            sys.stdout.write("\n")
    if not apps:
        apps = "."

    sys.stdout.write(f">>> Running pylint on {apps}\n")
    result = subprocess.run(
        shlex.split(f"pylint {apps} --rcfile=.pylintrc"),
        capture_output=True,
        check=False,  # Evita interrupções no processo.
    )
    if result.returncode != 0:
        print(f"Pylint retornou código {result.returncode}")
        print("Error:")
        print(result.stderr)

    stdout = result.stdout.decode("utf-8")
    stderr = result.stderr.decode("utf-8")

    if result.returncode != 0:
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        sys.stderr.write("\nPlease fix the listed errors! :)\n")
        sys.exit(1)
    else:
        print(">>>>>> No warnings found...")


if __name__ == "__main__":
    main()

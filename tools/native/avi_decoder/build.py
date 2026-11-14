"""Rebuild the AVI playback extension with MSVC 2019 and pinned public sources.

The supplied movies are never inputs to this build and are never re-encoded.
"""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import re
import shutil
import subprocess
import urllib.request
import zipfile
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
WORK = ROOT / "_work/native-avi-decoder"
PLUGIN = ROOT / "godot/chibi_remake/addons/ffmpegplayer"
LOCK = json.loads((HERE / "dependency-lock.json").read_text())


def download(url, target, sha256=None):
    if not target.exists():
        urllib.request.urlretrieve(url, target)
    if sha256 and hashlib.sha256(target.read_bytes()).hexdigest() != sha256:
        raise RuntimeError("Dependency checksum mismatch: " + str(target))
    return target


def source_tree(key, folder):
    item = LOCK[key]
    target = WORK / folder
    if target.exists():
        if (target / ".git").is_dir():
            verify_source(target, item["commit"])
            return
        # Preserve unverified legacy ZIP trees rather than trusting their comment.
        legacy = WORK / (folder + ".legacy-" + uuid.uuid4().hex)
        if not target.resolve().is_relative_to(WORK.resolve()) or legacy.parent.resolve() != WORK.resolve():
            raise RuntimeError("Unsafe legacy source cache")
        target.rename(legacy)
        print("Preserved unverified source cache: " + str(legacy))
    stage = Path(tempfile.mkdtemp(prefix=key + "-", dir=WORK))
    # Git checks the commit/tree/blob object hashes; HTTPS ZIP comments do not.
    git(stage, "init", "--quiet")
    git(stage, "remote", "add", "origin", item["repository"])
    git(stage, "-c", "fetch.fsckObjects=true", "fetch", "--depth=1", "origin", item["commit"])
    git(stage, "-c", "core.autocrlf=false", "checkout", "--detach", "FETCH_HEAD")
    git(stage, "submodule", "update", "--init", "--recursive", "--depth=1")
    verify_source(stage, item["commit"])
    stage.rename(target)


def git(directory, *arguments):
    return subprocess.check_output(["git", "-C", str(directory), *arguments], stderr=subprocess.STDOUT, text=True).strip()


def verify_source(directory, commit):
    if git(directory, "rev-parse", "HEAD") != commit:
        raise RuntimeError("Unexpected source commit: " + str(directory))
    git(directory, "fsck", "--full", "--no-dangling")
    if git(directory, "status", "--porcelain", "--untracked-files=no"):
        raise RuntimeError("Modified dependency sources: " + str(directory))
    for record in git(directory, "ls-files", "--stage").splitlines():
        metadata, name = record.split("\t", 1)
        mode, expected, _ = metadata.split()
        if mode == "160000":
            submodule = (directory / name).resolve()
            if not submodule.is_relative_to(directory.resolve()):
                raise RuntimeError("Unsafe source submodule")
            verify_source(submodule, expected)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(source_tree, "godotCpp", "godot-cpp-4.1"), pool.submit(source_tree, "ffmpeg", "FFmpeg-n6.1.2")]
        for job in jobs:
            job.result()
    shutil.copytree(HERE / "src", WORK / "src", dirs_exist_ok=True)
    shutil.copyfile(HERE / "CMakeLists.txt", WORK / "CMakeLists.txt")
    (WORK / "FFmpeg-n6.1.2/libavutil/avconfig.h").write_text("#define AV_HAVE_BIGENDIAN 0\n#define AV_HAVE_FAST_UNALIGNED 1\n")

    vswhere = Path("C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe")
    install = Path(subprocess.check_output([str(vswhere), "-version", "[16.0,17.0)", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"], text=True).splitlines()[0])
    compiler = sorted((install / "VC/Tools/MSVC").iterdir())[-1] / "bin/Hostx64/x64"
    cmake = install / "Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
    if not cmake.exists():
        cmake = Path(shutil.which("cmake") or "cmake")

    runtime = PLUGIN / "win64"
    runtime.mkdir(parents=True, exist_ok=True)
    if not (runtime / "avcodec-60.dll").exists():
        item = LOCK["extension"]
        archive = download(item["release"], WORK / "ffmpegplayer.zip", item["sha256"])
        with zipfile.ZipFile(archive) as package:
            for name in package.namelist():
                if name.startswith("ffmpegplayer/win64/") and name.endswith(".dll"):
                    (runtime / Path(name).name).write_bytes(package.read(name))
    imports = WORK / "lib"
    imports.mkdir(exist_ok=True)
    for name in ["avcodec-60", "avformat-60", "avutil-58", "swresample-4", "swscale-7"]:
        output = subprocess.check_output([str(compiler / "dumpbin.exe"), "/exports", str(runtime / (name + ".dll"))], text=True)
        symbols = re.findall(r"^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\w+)", output, re.M)
        if not symbols:
            raise RuntimeError("No native exports: " + name)
        definition = imports / (name + ".def")
        definition.write_text("LIBRARY " + name + ".dll\nEXPORTS\n" + "\n".join(symbols) + "\n")
        subprocess.run([str(compiler / "lib.exe"), "/nologo", "/machine:x64", "/def:" + str(definition), "/out:" + str(imports / (name.split("-")[0] + ".lib"))], check=True)
    build = WORK / "build"
    subprocess.run([str(cmake), "-S", str(WORK), "-B", str(build), "-G", "Visual Studio 16 2019", "-A", "x64", "-DCMAKE_BUILD_TYPE=Release"], check=True)
    subprocess.run([str(cmake), "--build", str(build), "--config", "Release", "--parallel", "12"], check=True)
    shutil.copyfile(build / "Release/FFmpegPlayer.dll", runtime / "FFmpegPlayer.dll")
    redist = sorted((install / "VC/Redist/MSVC").iterdir())[-1] / "x64/Microsoft.VC142.CRT"
    for name in ["msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll"]:
        shutil.copyfile(redist / name, runtime / name)
    print("Native AVI decoder rebuilt; original media unchanged.")


if __name__ == "__main__":
    main()

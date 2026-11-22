"""Rebuild the optional Windows pure simulation math kernel, with pinned inputs."""
from pathlib import Path
import hashlib, json, subprocess, urllib.request, zipfile, io, shutil, argparse
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
WORK=ROOT/"_work/sim-math"
DEP=WORK/"godot-cpp"
LOCK=json.loads((HERE/"dependency-lock.json").read_text())
def sha(data):return hashlib.sha256(data).hexdigest()
def verify_dependency():
    WORK.mkdir(parents=True,exist_ok=True)
    archive=WORK/"godot-cpp.zip"
    if not archive.exists():archive.write_bytes(urllib.request.urlopen(LOCK["url"],timeout=90).read())
    data=archive.read_bytes()
    if sha(data)!=LOCK["sha256"]:raise RuntimeError("godot-cpp archive checksum mismatch")
    expected=set()
    with zipfile.ZipFile(io.BytesIO(data)) as package:
        prefix=package.namelist()[0]
        for name in package.namelist():
            if name.endswith("/"):continue
            relative=Path(name).relative_to(prefix);target=DEP/relative
            if not target.resolve().is_relative_to(DEP.resolve()):raise RuntimeError("Unsafe dependency path")
            original=package.read(name);expected.add(relative.as_posix())
            if target.exists() and target.read_bytes()!=original:raise RuntimeError("Modified pinned dependency: "+str(relative))
            if not target.exists():target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(original)
    for folder in ["src","include","gdextension"]:
        for file in (DEP/folder).rglob("*"):
            if file.is_file() and file.relative_to(DEP).as_posix() not in expected:raise RuntimeError("Unexpected dependency source: "+str(file))
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--check",action="store_true");args=parser.parse_args()
    signature=sha((HERE/"sim_math.cpp").read_bytes().replace(b"\r\n",b"\n"))
    metadata=ROOT/"godot/chibi_remake/data/db/native_math.json"
    if args.check:
        if json.loads(metadata.read_text())["sourceSignature"]!=signature:raise RuntimeError("Native source identity stale; rebuild math kernel")
        print("NATIVE MATH SOURCE PASS");return
    verify_dependency()
    vswhere=Path("C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe")
    install=Path(subprocess.check_output([str(vswhere),"-version","[16.0,17.0)","-products","*","-requires","Microsoft.VisualStudio.Component.VC.Tools.x86.x64","-property","installationPath"],text=True).splitlines()[0])
    cmake=install/"Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe"
    if not cmake.exists():cmake=Path(shutil.which("cmake") or "cmake")
    subprocess.run([str(cmake),"-S",str(HERE),"-B",str(WORK/"build"),"-G","Visual Studio 16 2019","-A","x64","-DSIM_SIGNATURE="+signature],check=True)
    subprocess.run([str(cmake),"--build",str(WORK/"build"),"--config","Release","--parallel","8"],check=True)
    output=ROOT/"godot/chibi_remake/simulation/native/bin/ChibiSimulationMath.dll"
    output.parent.mkdir(parents=True,exist_ok=True)
    staged=output.with_suffix(".dll.build")
    try:
        shutil.copyfile(WORK/"build/Release/ChibiSimulationMath.dll",staged);staged.replace(output)
    finally:staged.unlink(missing_ok=True)
    metadata.write_text(json.dumps({"schemaVersion":1,"sourceSignature":signature,"bindingsCommit":LOCK["commit"],"algorithm":"dictionary-math-v1"},indent=2)+"\n")
    print("NATIVE MATH BUILT",output)
if __name__=="__main__":main()

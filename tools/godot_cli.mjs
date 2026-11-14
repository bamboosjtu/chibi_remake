import path from 'node:path';import {spawn} from 'node:child_process';
// PowerShell may return immediately for a GUI-subsystem SDK executable. Node
// waits for the actual child, including import/export failure exit codes.
const [engine,...args]=process.argv.slice(2);
if(!engine)throw Error('Usage: node tools/godot_cli.mjs <reviewed engine> <arguments...>');
const child=spawn(path.resolve(engine),args,{windowsHide:true,stdio:'inherit'});
child.on('error',error=>{console.error(error);process.exitCode=1;});
child.on('close',code=>{process.exitCode=code??1;});

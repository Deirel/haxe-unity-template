import hx.files.*;
import haxe.macro.Context;

class PostBuild {
    static var cwd:Dir;

    static var unityScriptsDir:Dir;
    static var haxeScriptsDir:Dir;
    static var excludeFilePath:String;

    public static function task() {
        var unityScriptsDef = Context.definedValue("unity-sources-path");
        var haxeScriptsDef = Context.definedValue("haxe-sources-path");
        var excludeClassDef = Context.definedValue("exclude-class");

        cwd = Dir.of(Sys.getCwd());

        unityScriptsDir = cwd.path.join(unityScriptsDef).toDir();
        haxeScriptsDir = cwd.path.join(haxeScriptsDef).toDir();
        excludeFilePath = haxeScriptsDir.path.join(excludeClassDef + ".cs").toString();

        actualizeSources();
    }

    static function actualizeSources() {
        var unityList = listRecursively(unityScriptsDir);
        var haxeList = listRecursively(haxeScriptsDir);

        // --- Remove excess unity files ---
        var unityRelPathIndex = unityScriptsDir.toString().length;
        for (file in unityList.files) {
            var relPath = file.toString().substr(unityRelPathIndex);
            var haxePath = haxeScriptsDir.path.join(relPath);
            if (!haxePath.exists()) {
                trace('Remove $file');
                
                file.delete();

                var fileMeta = file.path.parent.join(file.path.filenameStem + ".meta").toFile();
                fileMeta.delete();
            }
        }

        // --- Remove excess unity dirs ---
        for (dir in unityList.dirs) {
            if (dir.isEmpty()) {
                dir.delete();
            }
        }

        // --- Copy changed haxe files ---
        var haxeRelPathIndex = haxeScriptsDir.toString().length;
        for (file in haxeList.files) {
            if (file.path.toString() == excludeFilePath)
                continue;

            var relPath = file.toString().substr(haxeRelPathIndex);
            var unityPath = unityScriptsDir.path.join(relPath);
            if (unityPath.exists()) {
                var unityFile = unityPath.toFile();
                if (areFilesEqual(file, unityFile)) {
                    continue;
                }
            }

            // --- Create directories if needed ---
            var parentDir = unityPath.parent;
            if (!parentDir.exists()) {
                parentDir.toDir().create();
            }

            trace('Copy $file');
            file.copyTo(unityPath, [OVERWRITE]);
        }
    }

    static function areFilesEqual(file1:File, file2:File) {
        return file1.readAsBytes().compare(file2.readAsBytes()) == 0;
    }

    static function listRecursively(dir:Dir):{ files:Array<File>, dirs:Array<Dir> } {
        var files = [];
        var dirs = [];

        (function listRec(dir:Dir) {
            for (path in dir.list()) {
                if (path.isFile()) {
                    files.push(path.toFile());
                }
                else {
                    var childDir = path.toDir();
                    dirs.push(childDir);
                    listRec(childDir);
                }
            }
        })(dir);

        return {
            files: files,
            dirs: dirs
        }
    }
}
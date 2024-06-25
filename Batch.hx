import sys.io.Process;

using StringTools;

class Batch {
	static inline var IDECKIA_GIT_BASE = '/home/josu/git/ideckia';
	static inline var IDECKIA_APP_DIR = '/home/josu/ideckia';
	static inline var GIT_USER = 'josuigoa';
	static inline var GIT_MAIL = 'josuigoa@ni.eus';

	static var actions = [];

	static public function main() {
		var base = '$IDECKIA_GIT_BASE/actions/';
		final ignoreActions = [];
		for (d in sys.FileSystem.readDirectory(base)) {
			if (!sys.FileSystem.isDirectory(base + d))
				continue;
			if (ignoreActions.contains('action_$d'))
				continue;
			trace(d);
			Sys.setCwd(base + d);
			// updateApi();
			// localApi(d);
			// haxeCompile(false); // build
			// haxeCompile(true); // deploy
			// gitStatus(d);
			// gitReleaseStart(d);
			// gitReleaseFinish(d);
			// gitPush(d);
			// gitPushLastTag(d);
			// trace(gitNextTag());
			copyToIdeckia(d);
			// gitSetUser({name: GIT_USER, mail: GIT_MAIL});
			// gitGetBranchName(d);
			// gitRenameMain();
		}

		if (actions.length > 0)
			trace('Actions:\n  ' + actions.join('\n  '));
	}

	static function updateApi() {
		if (!sys.FileSystem.exists('.haxerc'))
			return;
		Sys.command('lix install gh:ideckia/ideckia_api');
	}

	static function localApi(actionName:String) {
		if (!sys.FileSystem.exists('.haxerc'))
			return;
		var c = sys.io.File.getContent('$IDECKIA_GIT_BASE/ideckia_core/haxe_libraries/ideckia_api.hxml');
		try {
			sys.io.File.saveContent('./haxe_libraries/ideckia_api.hxml', c);
		} catch (e:haxe.Exception) {
			trace(e);
		}
	}

	static function haxeCompile(deploy:Bool = false) {
		var filename = deploy ? 'deploy.hxml' : 'build.hxml';
		if (!sys.FileSystem.exists(filename))
			return;
		filename = deploy ? 'deploy_all.hxml' : 'build_all.hxml';
		if (!sys.FileSystem.exists(filename))
			return;
		Sys.command('haxe $filename');
	}

	static function gitStatus(actionName:String) {
		if (!sys.FileSystem.exists('.git'))
			return;
		var p = new Process('git status');
		if (p.exitCode() != 0) {
			trace('Error: ${p.stderr.readAll().toString()}');
			return;
		}

		actions.push(actionName);
		var out = '';
		while (out != null) {
			try {
				out = p.stdout.readLine();

				if (out.indexOf("nothing to commit") != -1)
					actions.pop();
			} catch (e:Any) {
				break;
			}
		}
	}

	static function gitPush(actionName:String) {
		if (!sys.FileSystem.exists('.git'))
			return;
		var p = new Process('git push origin ');
		if (p.exitCode() != 0) {
			trace('Error: ${p.stderr.readAll().toString()}');
			return;
		}

		actions.push(actionName);
	}

	static function gitLastTag() {
		if (!sys.FileSystem.exists('.git'))
			return '';
		var p = new Process('git rev-list --tags --max-count=1');

		var lastTag = '';
		if (p.exitCode() != 0) {
			trace('Error: ${p.stderr.readAll().toString()}');
			return '';
		}
		try {
			var out = p.stdout.readLine();
			p = new Process('git describe $out');
			if (p.exitCode() != 0) {
				trace('Error: ${p.stderr.readAll().toString()}');
				return '';
			}

			out = p.stdout.readLine();

			if (out != '') {
				lastTag = out;
			}
		} catch (e:Any) {
			trace(e);
		}

		return lastTag;
	}

	static function gitPushLastTag(actionName:String) {
		if (!sys.FileSystem.exists('.git'))
			return;

		var lastTag = gitLastTag();
		if (lastTag == '')
			return;

		var p = new Process('git push origin $lastTag');
		if (p.exitCode() != 0) {
			trace('Error: ${p.stderr.readAll().toString()}');
			return;
		}

		actions.push(actionName);
	}

	static function gitNextTag() {
		var lastTag = gitLastTag();
		if (lastTag == '')
			return '';
		var firstPart = lastTag.substring(0, lastTag.lastIndexOf('.') + 1);
		var lastNumber = Std.parseInt(lastTag.substring(lastTag.lastIndexOf('.') + 1, lastTag.length));

		return firstPart + Std.string(lastNumber + 1);
	}

	static function gitReleaseStart(actionName:String) {
		if (!sys.FileSystem.exists('.git'))
			return;

		var nextTag = gitNextTag();
		if (nextTag == '')
			return;
		if (nextTag == 'Eof')
			nextTag = 'v1.0.0';

		var p = new Process('git flow release start $nextTag');
		if (p.exitCode() != 0) {
			trace('Error: ${p.stderr.readAll().toString()}');
			return;
		}
		actions.push(actionName + ' - start release - next : $nextTag');
	}

	static function gitReleaseFinish(actionName:String) {
		if (!sys.FileSystem.exists('.git'))
			return;

		var nextTag = gitNextTag();
		if (nextTag == '')
			return;

		var p = new Process('git flow release finish $nextTag -m $nextTag');
		if (p.exitCode() != 0) {
			trace('Error: ${p.stderr.readAll().toString()}');
			return;
		}
		actions.push(actionName + ' - release finish: $nextTag');
	}

	static function gitSetUser(user:{name:String, mail:String}) {
		if (!sys.FileSystem.exists('.git'))
			return;
		var p = new Process('git config user.name "${user.name}"');
		if (p.exitCode() != 0) {
			trace('Error "git config user.name": ${p.stderr.readAll().toString()}');
			return;
		}
		p = new Process('git config user.email "${user.mail}"');
		if (p.exitCode() != 0) {
			trace('Error "git config user.email": ${p.stderr.readAll().toString()}');
			return;
		}
	}

	static function gitGetBranchName(actionName:String) {
		if (!sys.FileSystem.exists('.git'))
			return;
		var p = new Process('git branch --show-current');
		if (p.exitCode() != 0) {
			trace('Error gitGetBranchName: ${p.stderr.readAll().toString()}');
			return;
		}
		try {
			var out = p.stdout.readLine();
			actions.push('$actionName / $out');
		} catch (e:Any) {
			trace(e);
		}
	}

	static function gitRenameMain() {
		if (!sys.FileSystem.exists('.git'))
			return;

		var p = new Process('git branch -m main');
		if (p.exitCode() != 0) {
			trace('Error gitGetBranchName: ${p.stderr.readAll().toString()}');
			return;
		}
	}

	static function copyToIdeckia(actionName:String) {
		copyIndex(actionName);
		copyLoc(actionName);
	}

	static function copyIndex(actionName:String) {
		if (!sys.FileSystem.exists('index.js'))
			return;
		else if (sys.FileSystem.exists('move.sh')) {
			var p = new Process('./move.sh');
			if (p.exitCode() != 0) {
				trace('Error moving: ${p.stderr.readAll().toString()}');
				return;
			}
			return;
		}
		var indexContent = sys.io.File.getContent('index.js');
		var actionDir = actionName.replace('action_', '');
		try {
			sys.io.File.saveContent('$IDECKIA_APP_DIR/actions/$actionDir/index.js', indexContent);
		} catch (e:haxe.Exception) {
			trace(e);
		}
	}

	static function copyLoc(actionName:String) {
		if (!sys.FileSystem.exists('loc/'))
			return;
		var actionDir = actionName.replace('action_', '');
		try {
			var enContent = sys.io.File.getContent('loc/en_UK.json');
			var euContent = sys.io.File.getContent('loc/eu_ES.json');
			if (!sys.FileSystem.exists('$IDECKIA_APP_DIR/actions/$actionDir/loc/'))
				sys.FileSystem.createDirectory('$IDECKIA_APP_DIR/actions/$actionDir/loc/');

			sys.io.File.saveContent('$IDECKIA_APP_DIR/actions/$actionDir/loc/en_UK.json', enContent);
			sys.io.File.saveContent('$IDECKIA_APP_DIR/actions/$actionDir/loc/eu_ES.json', euContent);
		} catch (e:haxe.Exception) {
			trace(e);
		}
	}
}

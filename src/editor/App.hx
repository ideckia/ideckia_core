package;

import api.internal.CoreApi;
import js.Browser.document;
import js.html.*;

using api.IdeckiaApi;
using hx.Selectors;

typedef IconData = {
	var name:String;
	var base64:String;
}

class App {
	static var websocket:js.html.WebSocket;
	public static var editorData:EditorData;
	public static var icons:Array<IconData>;
	public static var dirtyData(default, set):Bool = false;

	public static function set_dirtyData(dd:Bool) {
		dirtyData = dd;
		if (dd)
			Id.update_core_layout_btn.get().classList.remove(Cls.hidden);
		else
			Id.update_core_layout_btn.get().classList.add(Cls.hidden);
		return dd;
	}

	function new() {
		js.Browser.window.onload = onLoad;
	}

	function onLoad() {
		initWebsocketCore();

		js.Browser.window.addEventListener('beforeunload', (e:Event) -> {
			if (dirtyData) {
				e.preventDefault();
				e.returnValue = false;
			}
		});

		Id.dir_select.get().addEventListener('change', (event) -> {
			if (editorData == null)
				return;
			var selectedIndex = Std.parseInt(Id.dir_select.as(SelectElement).value);
			var currentDir = editorData.layout.dirs[selectedIndex];

			ItemEditor.hide();
			StateEditor.hide();
			ActionEditor.hide();

			DirEditor.show(currentDir);
		});

		Id.add_dir_btn.get().addEventListener('click', (_) -> {
			var layoutRows = editorData.layout.rows;
			var layoutColumns = editorData.layout.columns;

			Id.new_dir_name.as(InputElement).value = '';
			Id.new_dir_rows.as(InputElement).value = Std.string(layoutRows);
			Id.new_dir_columns.as(InputElement).value = Std.string(layoutColumns);

			Dialog.show('::show_title_new_dir::', Id.new_dir.get(), () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var newDirName = Id.new_dir_name.as(InputElement).value;
					if (newDirName == null || newDirName == '') {
						js.Browser.alert('::alert_create_dir_empty_name::');
						resolve(false);
					}

					var dirs = editorData.layout.dirs;
					if (dirs.filter(d -> d.name.toString() == newDirName).length > 0) {
						js.Browser.alert(Utils.formatString('::alert_create_dir_existing::', [newDirName]));
						resolve(false);
					}

					var newDir:Dir = {
						name: new DirName(newDirName),
						items: []
					};

					var newRows = Std.parseInt(Id.new_dir_rows.as(InputElement).value);
					var newColumns = Std.parseInt(Id.new_dir_columns.as(InputElement).value);

					newDir.rows = newRows;
					newDir.columns = newColumns;
					var itemCount = newRows * newColumns;

					if (App.editorData.layout.dirs.length > 0) {
						var firstDirName = App.editorData.layout.dirs[0].name;
						newDir.items.push({
							id: Utils.getNextItemId(),
							kind: ChangeDir(firstDirName, {id: Utils.getNextStateId(), text: 'back to $firstDirName'})
						});
						itemCount--;
					}

					for (_ in 0...itemCount)
						newDir.items.push({id: Utils.getNextItemId()});

					dirs.push(newDir);

					App.dirtyData = true;

					updateDirsSelect(true);
					resolve(true);
				});
			});
		});

		Id.add_fixed_item_btn.get().addEventListener('click', (_) -> {
			Utils.createNewItem().then(item -> {
				if (editorData.layout.fixedItems == null)
					editorData.layout.fixedItems = [];
				editorData.layout.fixedItems.push(item);
				App.dirtyData = true;
				FixedEditor.show();
			}).catchError(error -> trace(error));
		});

		Id.delete_dir_btn.get().addEventListener('click', (_) -> {
			var currentDir = @:privateAccess DirEditor.currentDir;
			if (js.Browser.window.confirm(Utils.formatString('::confirm_delete_dir::', [currentDir.name.toString()]))) {
				var dirs = editorData.layout.dirs;
				dirs.remove(currentDir);
				App.dirtyData = true;
				updateDirsSelect();
			}
		});

		Id.append_layout_btn.get().addEventListener('click', (_) -> {
			Id.append_layout_input.as(InputElement).value = '';
			Dialog.show('::show_title_layout_append::', Id.append_layout.get(), () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var reader = new FileReader();
					var input = Id.append_layout_input.as(InputElement);

					reader.onload = function(e) {
						final port = js.Browser.location.port;
						var http = new haxe.Http('http://localhost:$port$layoutAppendEndpoint');
						http.addHeader('Content-Type', 'application/json');
						http.onError = (e) -> {
							var msg = Utils.formatString('::alert_append_error::', [e]);
							js.Browser.alert(msg);
							reject(msg);
						};
						http.onData = (d) -> {
							js.Browser.alert(Utils.formatString('::alert_append_ok::', [input.value]));
							resolve(true);
						};

						var cleanResult = new EReg("data:application/json;base64,", "").replace(reader.result, '');
						var layoutData = haxe.crypto.Base64.decode(cleanResult).toString();
						http.setPostData(layoutData);
						http.request(true);
					};

					reader.onerror = function(e) {
						var msg = 'Error loading layout: ' + e.type;
						trace(msg);
						reject(msg);
					};
					var apLayout = input.files.item(0);
					if (apLayout.type != 'application/json') {
						var msg = 'Invalid layout type. Must be "application/json".';
						js.Browser.alert(msg);
						reject(msg);
						return;
					}
					reader.readAsDataURL(apLayout);
				});
			});
		});

		Id.export_dir_btn.get().addEventListener('click', (_) -> {
			var exportDirsSelect = Id.export_dir_select.as(SelectElement);
			var options = exportDirsSelect.options;
			exportDirsSelect.style.height = '${Std.int(options.length * 1.5)}em';

			Dialog.show('::show_title_dir_export::', Id.export_dir.get(), () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var option:OptionElement;
					var selectedDirNames = [];
					for (i in 0...options.length) {
						option = cast options.item(i);
						if (option.selected) {
							trace(option);
							selectedDirNames.push(option.text);
						}
					}

					final port = js.Browser.location.port;
					var http = new haxe.Http('http://localhost:$port${directoryExportEndpoint}');
					http.addHeader('Content-Type', 'application/json');
					http.onError = (e) -> js.Browser.alert(Utils.formatString('::alert_export_dir_error::', [e]));
					http.onData = (d) -> {
						var anchor = document.createAnchorElement();
						anchor.href = 'data:application/json;charset=utf-8,' + haxe.Json.parse(d);
						anchor.download = 'ideckia-exported-dirs.json';
						anchor.style.display = 'none';
						document.body.appendChild(anchor);

						anchor.click();

						document.body.removeChild(anchor);
					}
					http.setPostData(haxe.Json.stringify(selectedDirNames));
					http.request(true);

					resolve(true);
				});
			});
		});
		Id.add_icon_btn.get().addEventListener('click', (_) -> {
			var reader = new FileReader();

			reader.onload = function(e) {
				Id.new_icon_base64.as(TextAreaElement).value = reader.result;
			};

			var iconNameInput = Id.new_icon_name.as(InputElement);
			reader.onerror = function(e) {
				trace('Error loading image: ' + e.type);
				iconNameInput.value = '';
			};

			iconNameInput.value = '';
			Id.new_icon_base64.as(TextAreaElement).value = '';
			Id.new_icon_drop_img.get().addEventListener('drop', (e:DragEvent) -> {
				Utils.stopPropagation(e);
				var dataTransfer = e.dataTransfer;
				if (dataTransfer.files.length > 0) {
					var image = dataTransfer.files.item(0);
					var validTypes = ['image/jpeg', 'image/png', 'image/gif'];
					if (validTypes.indexOf(image.type) == -1) {
						js.Browser.alert(Utils.formatString('::alert_invalid_file_type::', [validTypes.join(', ')]));
						return;
					}
					var maxSizeInBytes = 10e6; // 10MB
					if (image.size > maxSizeInBytes) {
						js.Browser.alert("File too large");
						return;
					}
					if (iconNameInput.value == '')
						Id.new_icon_name.as(InputElement).value = image.name;
					reader.readAsDataURL(image);
				}
			});
			Id.new_icon_drop_img.get().addEventListener('dragover', (e) -> Utils.stopPropagation(e));
			Id.new_icon_drop_img.get().addEventListener('dragenter', (e) -> {
				Utils.stopPropagation(e);
				Id.new_icon_drop_img.get().classList.add(Cls.icon_drag_over);
			});
			Id.new_icon_drop_img.get().addEventListener('dragleave', (e) -> {
				Utils.stopPropagation(e);
				Id.new_icon_drop_img.get().classList.remove(Cls.icon_drag_over);
			});
			Dialog.show('::show_title_new_icon::', Id.new_icon.get(), () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var iconName = Id.new_icon_name.as(InputElement).value;
					var iconData = Id.new_icon_base64.as(TextAreaElement).value;
					if (iconName == null || iconName == '') {
						js.Browser.alert('::alert_icon_name_empty::');
						resolve(false);
						return;
					}
					if (icons.filter(i -> i.name == iconName).length > 0) {
						js.Browser.alert(Utils.formatString('::alert_icon_name_existing::', [iconName]));
						resolve(false);
						return;
					}
					if (iconData == null || iconData == '') {
						js.Browser.alert('::alert_icon_base64_empty::');
						resolve(false);
						return;
					}
					editorData.layout.icons.push({
						key: iconName,
						value: iconData
					});
					updateIcons();
					App.dirtyData = true;
					resolve(true);
				});
			});
		});
		Id.remove_icon_btn.get().addEventListener('click', (_) -> {
			var container = document.createDivElement();
			var unusedIcons = Utils.getUnusedIcons();
			var tplClone, cbId;
			for (i in icons) {
				if (i.name == '')
					continue;
				tplClone = Utils.cloneElement(Id.remove_icon_tpl.get(), DivElement);
				cbId = 'remove-${i.name}-icon';
				switch Cls.remove_icon_name_cb.firstFromAs(tplClone, InputElement) {
					case Some(cb):
						cb.id = cbId;
						cb.disabled = !unusedIcons.contains(i.name);
						if (cb.disabled) {
							cb.title = 'This icon is used by some state, it cannot be removed.';
						}
					case None:
				}
				switch Cls.icon_name_label.firstFromAs(tplClone, LabelElement) {
					case Some(label):
						label.innerText = i.name;
						label.htmlFor = cbId;
					case None:
				}
				switch Cls.icon_preview.firstFromAs(tplClone, ImageElement) {
					case Some(img):
						img.src = Utils.defaultBase64Prefix(i.base64);
					case None:
				}

				container.appendChild(tplClone);
			}
			Dialog.show('::show_title_icon_remove::', container, () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var removed = [];
					for (c in container.children) {
						switch Cls.remove_icon_name_cb.firstFromAs(c, InputElement) {
							case Some(cb):
								if (cb.checked) {
									switch Cls.icon_name_label.firstFrom(c) {
										case Some(lbl):
											removed.push(lbl.innerText);
										case None:
									}
								}
							case None:
						}
					}
					if (removed.length != 0) {
						for (r in removed) {
							// remove from the editor icon list
							var foundIcons = icons.filter(i -> i.name == r);
							if (foundIcons.length != 0) {
								for (fi in foundIcons)
									icons.remove(fi);
							}
							var foundLayoutIcons = editorData.layout.icons.filter(i -> i.key == r);
							if (foundLayoutIcons.length != 0) {
								var iconNames = [];
								// remove from the layout icon list
								for (fli in foundLayoutIcons) {
									editorData.layout.icons.remove(fli);
									iconNames.push(fli.key);
								}

								// remove those icon references from states
								for (d in editorData.layout.dirs) {
									for (i in d.items) {
										switch i.kind {
											case null:
											case ChangeDir(_, state):
												if (state != null && state.icon != null && iconNames.indexOf(state.icon) != -1) state.icon = null;
											case States(_, list):
												for (s in list)
													if (s != null && s.icon != null && iconNames.indexOf(s.icon) != -1)
														s.icon = null;
										}
									}
								}
							}
						}

						js.Browser.window.alert('Icons removed: ${removed.join(',')}');
						App.dirtyData = true;
					}
					resolve(true);
				});
			});
		});
		Id.edit_shared_btn.get().addEventListener('click', (_) -> {
			var container:Element = document.createDivElement();
			var div;

			inline function createSharedDataDiv(key, value) {
				div = Utils.cloneElement(Id.shared_var_edit.get(), DivElement);

				switch Cls.shared_var_edit_key.firstFromAs(div, InputElement) {
					case Some(svKey):
						svKey.value = key;
					case None:
				}

				switch Cls.shared_var_edit_value.firstFromAs(div, InputElement) {
					case Some(svValue):
						svValue.value = value;
					case None:
				}

				return div;
			}

			container.appendChild(createSharedDataDiv('', ''));
			for (sv in editorData.layout.sharedVars) {
				container.appendChild(createSharedDataDiv(sv.key, sv.value));
			}
			Dialog.show('::show_title_shared_values::', container, () -> {
				return new js.lib.Promise((resolveDialog, _) -> {
					var svDivs = Cls.shared_var_edit.from(container);
					var newSharedVars = [];
					for (svDiv in svDivs) {
						switch Cls.shared_var_edit_key.firstFromAs(svDiv, InputElement) {
							case Some(svKey):
								if (svKey.value != '') {
									switch Cls.shared_var_edit_value.firstFromAs(svDiv, InputElement) {
										case Some(svValue):
											newSharedVars.push({key: svKey.value, value: svValue.value});
										case None:
									}
								}
							case None:
						}
					}
					editorData.layout.sharedVars = newSharedVars;
					App.dirtyData = true;
					Dialog.clear(true);
					resolveDialog(true);
				});
			});
		});
		Id.create_action_btn.get().addEventListener('click', (_) -> {
			final port = js.Browser.location.port;
			var http = new haxe.Http('http://localhost:$port$actionTemplatesEndpoint');
			http.onError = (e) -> {
				var msg = 'Error getting templates: $e';
				js.Browser.alert(msg);
			};
			http.onData = (d) -> {
				var templates:Array<TemplateDef> = haxe.Json.parse(d);
				var radiosDiv = Id.div_create_action_tpl_radios.as(DivElement);
				while (radiosDiv.children.length > 0)
					radiosDiv.removeChild(radiosDiv.firstChild);
				var radioInputsName = 'create-action-tpl-radio';

				for (tpl in templates) {
					var radioInput = document.createInputElement();
					var id = 'create-action-${tpl.tplName}-tpl';
					radioInput.type = 'radio';
					radioInput.id = id;
					radioInput.value = tpl.tplDirectory + '::' + tpl.tplName;
					radioInput.name = radioInputsName;
					radiosDiv.appendChild(radioInput);

					var radioLabel = document.createLabelElement();
					radioLabel.htmlFor = id;
					radioLabel.innerText = tpl.tplName;
					radioLabel.classList.add(Cls.create_action_tpl_label);
					radiosDiv.appendChild(radioLabel);
					radiosDiv.appendChild(document.createBRElement());
				}

				var actionNameInput = Id.create_action_name.as(InputElement);
				actionNameInput.value = '';
				var actionDescriptionInput = Id.create_action_description.as(InputElement);
				actionDescriptionInput.value = '';
				Dialog.show('::show_title_action_params::', Id.create_action_data.get(), () -> {
					return new js.lib.Promise((resolve, reject) -> {
						var actionName = actionNameInput.value;
						var actionDescription = actionDescriptionInput.value;

						if (actionName == '') {
							js.Browser.alert('::alert_action_name_empty::');
							resolve(false);
							return;
						}

						var selectedRadio = Std.downcast(Tag.input.specify('[name="$radioInputsName"]:checked'), InputElement);

						if (selectedRadio == null) {
							js.Browser.alert('::alert_action_tpl_empty::');
							resolve(false);
							return;
						}

						final port = js.Browser.location.port;
						var http = new haxe.Http('http://localhost:$port$newActionEndpoint');
						http.addHeader('Content-Type', 'application/json');
						http.onError = (e) -> {
							var msg = Utils.formatString('::alert_action_create_error::', [actionName]);
							js.Browser.alert(msg);
							reject(msg);
						};
						var status = -1;
						http.onStatus = (s) -> {
							status = s;
						}
						http.onData = (d) -> {
							if (status == 200)
								js.Browser.alert(Utils.formatString('::alert_action_create_ok::', [d]));
							else if (status == 500)
								js.Browser.alert(Utils.formatString('::alert_action_create_error::', [actionName]));
							resolve(true);
						};

						var tplDirName = selectedRadio.value.split('::');

						var body:CreateActionDef = {
							tplName: tplDirName[1],
							tplDirectory: tplDirName[0],
							name: actionName,
							description: actionDescription
						}

						http.setPostData(haxe.Json.stringify(body));
						http.request(true);
					});
				});
			};
			http.request();
		});
		Id.update_core_layout_btn.get().addEventListener('click', (_) -> {
			var rows, columns, maxLength;

			for (dir in editorData.layout.dirs) {
				rows = dir.rows == null ? App.editorData.layout.rows : dir.rows;
				columns = dir.columns == null ? App.editorData.layout.columns : dir.columns;
				maxLength = rows * columns;
				dir.items.splice(maxLength, dir.items.length);
			}
			var msg:EditorMsg = {
				type: EditorMsgType.saveLayout,
				whoami: editor,
				layout: editorData.layout
			};

			websocket.send(tink.Json.stringify(msg));
			dirtyData = false;
			Id.layout_updated.get().classList.remove(Cls.hidden);
			haxe.Timer.delay(() -> {
				Id.layout_updated.get().style.opacity = '0';
				haxe.Timer.delay(() -> {
					Id.layout_updated.get().classList.add(Cls.hidden);
					Id.layout_updated.get().style.opacity = '1';
				}, 3000);
			}, 10);
		});
		Id.localize_me_btn.get().addEventListener('click', (_) -> {
			final port = js.Browser.location.port;
			var http = new haxe.Http('http://localhost:$port$newLocalizationEndpoint');
			http.onError = (e) -> {
				js.Browser.alert(Utils.formatString('::alert_localizaation_create_error::', [e]));
			};
			http.onData = (d) -> {
				js.Browser.alert(Utils.formatString('::alert_localizaation_create_ok::', [d]));
			};
			http.request();
		});
	}

	public static function updateActionDescriptors() {
		return new js.lib.Promise((resolve, reject) -> {
			final port = js.Browser.location.port;
			var http = new haxe.Http('http://localhost:$port$actionDescriptorsEndpoint');
			http.onError = (e) -> {
				js.Browser.alert(Utils.formatString('::alert_get_descriptors_error::', [e]));
				reject(e);
			};
			http.onData = (d) -> {
				App.editorData.actionDescriptors = haxe.Json.parse(d);
				resolve(true);
			};
			http.request();
		});
	}

	public static function updateSharedValues(?newSharedVar:{key:String, value:Any}) {
		if (editorData.layout.sharedVars == null) {
			if (newSharedVar == null)
				return;

			editorData.layout.sharedVars = [];
		}

		if (newSharedVar != null) {
			var updated = false;
			for (index => variable in editorData.layout.sharedVars) {
				if (newSharedVar.key == variable.key) {
					editorData.layout.sharedVars[index] = newSharedVar;
					updated = true;
				}
			}
			if (!updated)
				editorData.layout.sharedVars.push(newSharedVar);
		}
		var datalist = Id.shared_vars_datalist.as(DataListElement);
		Utils.clearElement(datalist);

		var opt;
		for (sv in editorData.layout.sharedVars) {
			opt = js.Browser.document.createOptionElement();
			opt.value = '$' + sv.key;
			datalist.appendChild(opt);
		}
	}

	static public function getActionDescriptorByName(actionName:String):haxe.ds.Option<ActionDescriptor> {
		var f = editorData.actionDescriptors.filter(ad -> ad.name.toLowerCase() == actionName.toLowerCase());
		if (f.length == 0)
			return None;
		return Some(f[0]);
	}

	static public function getAllItems() {
		var allItems = [];
		for (dir in editorData.layout.dirs)
			for (i in dir.items)
				allItems.push(i);

		if (editorData.layout.fixedItems != null)
			allItems = allItems.concat(editorData.layout.fixedItems);

		return allItems;
	}

	static function updateDirsSelect(showLast:Bool = false) {
		var dirs = editorData.layout.dirs;
		for (selElement in Cls.dir_select.get()) {
			Utils.fillSelectElement(cast(selElement, SelectElement), [for (i in 0...dirs.length) {value: i, text: dirs[i].name.toString()}]);
		}

		if (dirs.length > 0) {
			Id.layout_container.get().classList.remove(Cls.hidden);
			Id.delete_dir_btn.get().classList.remove(Cls.hidden);
			if (showLast)
				DirEditor.show(dirs[dirs.length - 1]);
			else
				DirEditor.show(dirs[0]);
		} else {
			Id.layout_container.get().classList.add(Cls.hidden);
			Id.delete_dir_btn.get().classList.add(Cls.hidden);
		}
	}

	static function updateIcons() {
		icons = [
			for (i in App.editorData.layout.icons)
				{
					name: i.key,
					base64: i.value
				}
		];
		icons.insert(0, {name: '', base64: ''});
	}

	static function initWebsocketCore() {
		final port = js.Browser.location.port;
		websocket = new js.html.WebSocket('ws://127.0.0.1:${port}');

		websocket.onopen = () -> {
			var msg:EditorMsg = {
				type: EditorMsgType.getEditorData,
				whoami: editor
			};
			websocket.send(haxe.Json.stringify(msg));
		};

		websocket.onmessage = (event:{data:Any}) -> {
			var coreData:CoreMsg<Any> = haxe.Json.parse(event.data);
			switch coreData.type {
				case CoreMsgType.editorData:
					editorData = coreData.data;

					updateSharedValues();

					for (d in editorData.layout.dirs)
						DirEditor.addMissingItems(d, false);

					ItemEditor.hide();
					StateEditor.hide();
					ActionEditor.hide();

					updateIcons();

					updateDirsSelect();
					FixedEditor.show();

				case CoreMsgType.layout:
					if (!App.dirtyData) {
						var msg:EditorMsg = {
							type: EditorMsgType.getEditorData,
							whoami: editor
						};
						websocket.send(haxe.Json.stringify(msg));
					}

				case _:
					trace('Unhandled message [${coreData.type}] from core [${haxe.Json.stringify(event)}]');
			};
		}

		websocket.onerror = (event) -> {
			var msg = 'WebSocket connection to "${event.target.url}" failed.';
			trace(msg);
			js.Browser.alert(msg);
		}
	}

	public static function onItemClick(itemId:UInt) {
		if (Id.execute_actions_cb.as(InputElement).checked) {
			websocket.send(haxe.Json.stringify({
				type: click,
				whoami: client,
				itemId: itemId,
			}));
		}
	}

	public static function onItemLongPress(itemId:UInt) {
		if (Id.execute_actions_cb.as(InputElement).checked) {
			websocket.send(haxe.Json.stringify({
				type: longPress,
				whoami: client,
				itemId: itemId,
			}));
		}
	}

	static function main() {
		new App();
	}
}

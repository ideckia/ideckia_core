import js.html.ButtonElement;
import js.lib.intl.Collator.Usage;
import js.lib.RegExp;
import js.html.Element;
import js.html.ImageElement;
import api.internal.CoreApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.DivElement;
import js.html.Event;
import js.html.SelectElement;
import haxe.ds.Option;

using StringTools;

class ItemEditor {
	static var editingItem:CoreItem;
	static var isFixedItem:Bool;
	static var draggingStateIndex:UInt;
	static var listeners:Array<Utils.Listener> = [];
	static var cellListeners:Array<Utils.Listener> = [];

	public static function show(item:CoreItem, buttonSize:Float = 100., isFixed:Bool = false):Option<Element> {
		if (item == null)
			return None;

		var cell = Utils.cloneElement(Id.layout_grid_item_tpl.get(), ButtonElement);
		cell.dataset.item_id = Std.string(item.id.toUInt());

		var text = '';
		var state = null, defaultClass = null;
		switch item.kind {
			case null:
				text = 'empty';
			case ChangeDir(_, s):
				state = s;
				text = state.text;
				defaultClass = 'dir';
			case States(index, list):
				if (index == null)
					index = 0;
				state = list[index];
				text = state.text;
				defaultClass = 'states';
		};

		var textPosition = Cls.layout_bottom_text;
		var bgColor = null;
		var txtColor = 'white';

		if (state != null) {
			textPosition = switch state.textPosition {
				case top:
					Cls.layout_top_text;
				case center:
					Cls.layout_center_text;
				default:
					Cls.layout_bottom_text;
			}
			txtColor = state.textColor != null ? '#' + state.textColor.substr(2) : 'white';
			bgColor = (state.bgColor != null) ? cell.style.backgroundColor = '#' + state.bgColor.substr(2) : null;
		}

		cell.innerHTML = '<span>${recursiveModificators(text)}</span>';
		cell.style.color = txtColor;
		cell.style.width = '${buttonSize}px';
		cell.style.height = '${buttonSize}px';
		if (bgColor != null) {
			cell.style.backgroundColor = bgColor;
		} else if (defaultClass != null) {
			cell.classList.add(defaultClass);
		}
		cell.classList.add(textPosition);
		cell.style.backgroundImage = getIconUrl(state);
		cell.style.backgroundSize = '${buttonSize * .5}px';
		cell.style.borderRadius = '${buttonSize * 0.3}px';

		cell.addEventListener('click', (event:Event) -> {
			Utils.stopPropagation(event);
			Utils.selectElement(cell);
			Utils.hideAllProps();

			edit(item, isFixed);
		});

		return Some(cell);
	}

	static function recursiveModificators(text:String) {
		final regex = ~/{(.*)}/gm;
		if (text == null)
			return '';
		if (!regex.match(text))
			return text;

		var modif;
		while (regex.match(text)) {
			modif = regex.matched(0);
			text = text.replace(modif, processModificators(modif.substring(1, modif.length - 1)));
			modif = modif.substring(1, modif.length - 1);
		}

		return text;
	}

	static function processModificators(text:String) {
		var styleControl = text;
		var actualText = text;

		var isControl = text.startsWith("b:") || text.startsWith("i:") || text.startsWith("u:") || text.startsWith("color.") || text.startsWith("size.");

		if (isControl) {
			final colonIndex = text.indexOf(":");
			styleControl = text.substring(0, colonIndex);
			actualText = text.substring(colonIndex + 1, text.length);
		}
		if (styleControl == "b" || styleControl == "i" || styleControl == "u")
			return ("<" + styleControl + ">" + actualText + "</" + styleControl + ">");
		if (styleControl.startsWith("emoji.")) {
			var emojis = text.replace("emoji.", "").split(",");

			text = "";
			for (e in emojis)
				text += "&#" + Std.parseInt('0x' + e.trim()) + ";";
			return text;
		}
		if (styleControl.startsWith("color."))
			return ('<span style="color:#' + styleControl.replace("color.", "") + '">' + actualText + "</span>");
		if (styleControl.startsWith("size."))
			return ('<span style="font-size:' + styleControl.replace("size.", "") + 'px;">' + actualText + "</span>");
		return text;
	}

	static function getIconUrl(state:CoreState) {
		if (state == null || state.icon == null)
			return "";

		var icon = state.icon;

		if (icon == "" || icon == null)
			return "";
		var iconData = switch Utils.getIconIndexByName(state.icon) {
			case Some(index):
				App.icons[index].base64;
			case None:
				state.icon;
		};
		if (iconData == null) {
			final iconUrl = !icon.contains("base64,") ? "data:image/png;base64," + icon : icon;
			return 'url("' + iconUrl + '")';
		}

		if (iconData.contains("<svg")) {
			iconData = ~/\\<\\?xml.+\\?\\>|\\<\\!DOCTYPE.+]\\>/g.replace(iconData, ' ');
			iconData = ~/%3D/g.replace(iconData, '=');
			iconData = ~/%3A/g.replace(iconData, ':');
			iconData = ~/%2F/g.replace(iconData, '/');
			iconData = ~/%22/g.replace(iconData, "'");
			return 'url("data:image/svg+xml;charset=utf-8,' + iconData.urlEncode() + '")';
		}

		final iconUrl = !iconData.contains("base64,") ? "data:image/png;base64," + iconData : iconData;
		return 'url("' + iconUrl + '")';
	}

	public static function refresh() {
		var oldItem = editingItem;
		hide();
		edit(oldItem, isFixedItem);
	}

	public static function edit(item:CoreItem, isFixed:Bool) {
		editingItem = item;
		isFixedItem = isFixed;

		Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (event) -> {
			Utils.stopPropagation(event);

			switch editingItem.kind {
				case States(_, states):
					var state = Utils.createNewState();
					states.push(state);
					edit(editingItem, isFixedItem);
					StateEditor.edit(state);
				default:
			}
		});

		Utils.addListener(listeners, Id.clear_item_btn.get(), 'click', (event) -> {
			Utils.stopPropagation(event);
			if (js.Browser.window.confirm('::confirm_clear_item::')) {
				editingItem.kind = null;
				App.dirtyData = true;
				StateEditor.hide();
				ItemEditor.hide();
				ActionEditor.hide();
				DirEditor.refresh();
				FixedEditor.show();
			}
		});

		if (isFixed) {
			Id.remove_item_btn.get().classList.remove(Cls.hidden);
			Utils.addListener(listeners, Id.remove_item_btn.get(), 'click', (event) -> {
				Utils.stopPropagation(event);
				if (js.Browser.window.confirm('::confirm_remove_item::')) {
					editingItem.kind = null;

					function removeItem(items:Array<CoreItem>) {
						for (i in items) {
							if (i.id == editingItem.id) {
								items.remove(i);
								return true;
							}
						}
						return false;
					}

					if (!removeItem(@:privateAccess DirEditor.currentDir.items)) {
						removeItem(App.editorData.layout.fixedItems);
					}
					App.dirtyData = true;
					StateEditor.hide();
					ItemEditor.hide();
					ActionEditor.hide();
					DirEditor.refresh();
					FixedEditor.show();
				}
			});
		} else {
			Id.remove_item_btn.get().classList.add(Cls.hidden);
		}

		Id.item_type_container.get().classList.remove(Cls.hidden);
		Id.add_state_btn.get().classList.add(Cls.hidden);
		Id.clear_item_btn.get().classList.add(Cls.hidden);
		Id.item_kind_changedir_properties.get().classList.add(Cls.hidden);
		Id.item_kind_states_properties.get().classList.add(Cls.hidden);
		Id.add_item_kind_btn.get().classList.add(Cls.hidden);
		switch editingItem.kind {
			case ChangeDir(toDir, state):
				Id.add_state_btn.get().classList.add(Cls.hidden);
				Id.clear_item_btn.get().classList.remove(Cls.hidden);
				var select = Id.to_dir_select.as(SelectElement);
				var children = select.children;
				for (cind in 0...children.length) {
					if (children.item(cind).textContent == toDir.toString()) {
						select.selectedIndex = cind;
					}
				}

				StateEditor.edit(state);
				Id.item_kind_changedir_properties.get().classList.remove(Cls.hidden);

				Utils.addListener(listeners, select, 'change', onToDirChange);
			case States(_, states):
				Id.add_state_btn.get().classList.remove(Cls.hidden);
				Id.clear_item_btn.get().classList.remove(Cls.hidden);
				var parentDiv = Id.item_kind_states_properties.get();
				parentDiv.classList.remove(Cls.hidden);
				Utils.clearElement(parentDiv);
				var ulLabel = document.createLabelElement();
				ulLabel.textContent = '::text_content_states_upper::';
				parentDiv.append(ulLabel);
				var uList = document.createUListElement();
				var li;
				var deletable = states.length > 1;
				for (i in 0...states.length) {
					li = StateEditor.show(states[i], deletable);
					li.dataset.state_id = Std.string(states[i].id.toUInt());
					uList.append(li);
				}
				parentDiv.append(uList);
				for (d in Cls.draggable_state.from(uList)) {
					Utils.addListener(listeners, d, 'dragstart', (_) -> onDragStart(d.dataset.state_id));
					Utils.addListener(listeners, d, 'dragover', onDragOver);
					Utils.addListener(listeners, d, 'dragleave', onDragLeave);
					Utils.addListener(listeners, d, 'drop', (e) -> onDrop(e, item));
				}

				Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (_) -> {});
			case null:
				Id.add_item_kind_btn.get().classList.remove(Cls.hidden);
				Utils.addListener(listeners, Id.add_item_kind_btn.get(), 'click', (_) -> {
					Utils.createNewItem().then((newItem) -> {
						editingItem.id = newItem.id;
						editingItem.kind = newItem.kind;
						App.dirtyData = true;
						DirEditor.refresh();
						refresh();
						return;
					}).catchError(error -> trace(error));
				});
		}
	}

	public static function hide() {
		editingItem = null;
		Utils.removeListeners(listeners);
		Id.item_type_container.get().classList.add(Cls.hidden);
		Id.item_kind_changedir_properties.get().classList.add(Cls.hidden);
	}

	static function onToDirChange(_) {
		switch editingItem.kind {
			case ChangeDir(_, state):
				var select = Id.to_dir_select.as(SelectElement);
				var children = select.children;
				editingItem.kind = ChangeDir(new DirName(children[select.selectedIndex].textContent), state);
				App.dirtyData = true;
			case _:
		}
	}

	static function onDragStart(stateId:String) {
		draggingStateIndex = Std.parseInt(stateId);
	}

	static function onDragOver(e:Event) {
		e.preventDefault();
		var targetElement = cast(e.currentTarget, Element);
		if (!targetElement.classList.contains(Cls.drag_over))
			targetElement.classList.add(Cls.drag_over);
	}

	static function onDragLeave(e:Event) {
		e.preventDefault();
		var targetElement = cast(e.currentTarget, Element);
		targetElement.classList.remove(Cls.drag_over);
	}

	static function onDrop(e:Event, item:CoreItem) {
		for (d in Cls.drag_over.get())
			d.classList.remove(Cls.drag_over);
		var targetStateIndex = Std.parseInt(cast(e.currentTarget, Element).dataset.state_id);

		switch item.kind {
			case States(index, list):
				var stateToMove = list.splice(draggingStateIndex, 1)[0];
				if (stateToMove != null) {
					list.insert(targetStateIndex, stateToMove);
					item.kind = States(index, list);
					App.dirtyData = true;
					DirEditor.refresh();
					refresh();
				}
			case _:
		}
	}
}

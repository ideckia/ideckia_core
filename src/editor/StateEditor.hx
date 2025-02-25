import api.IdeckiaApi.ActionStatus;
import api.IdeckiaApi.Endpoint;
import api.IdeckiaApi.PropEditorFieldType;
import api.IdeckiaApi.TextPosition;
import api.internal.CoreApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.Element;
import js.html.Event;
import js.html.ImageElement;
import js.html.InputElement;
import js.html.LIElement;
import js.html.SelectElement;

using StringTools;

class StateEditor {
	static var editingState:CoreState;
	static var draggingActionIndex:UInt;

	static var listeners:Array<Utils.Listener> = [];

	public static function show(state:CoreState, deletable:Bool) {
		Id.item_kind_states_properties.get().classList.remove(Cls.hidden);
		var parentLi = Utils.cloneElement(Id.state_list_item_tpl.get(), LIElement);
		switch Tag.span.firstFrom(parentLi) {
			case Some(v):
				var iconText = (state.icon == null) ? '' : Utils.formatString('::state_list_icon::', [state.icon.substr(0, 30)]);
				v.innerText = Utils.formatString('::state_list_text::', [state.text, iconText]);
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
		}

		if (!deletable)
			switch Cls.delete_btn.firstFrom(parentLi) {
				case Some(v):
					v.classList.add(Cls.hidden);
				case None:
					trace('No [${Cls.delete_btn.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
			};

		if (state.actions != null) {
			final port = js.Browser.location.port;
			final endpoint = Endpoint.stateActionsForId(state.id.toUInt());
			var http = new haxe.Http('http://localhost:$port/$endpoint');
			http.addHeader('Content-Type', 'application/json');
			http.onError = (e) -> js.Browser.alert(Utils.formatString('::alert_getting_state_action_statuses::', [Std.string(state.id), e]));
			http.onData = (d) -> {
				var statuses:Map<UInt, ActionStatus> = haxe.Json.parse(d);

				var ulActions = document.createUListElement();
				var liAction, sAction;
				for (i in 0...state.actions.length) {
					sAction = state.actions[i];
					liAction = ActionEditor.show(sAction, statuses.get(sAction.id.toUInt()), state);
					liAction.dataset.action_id = Std.string(sAction.id.toUInt());
					ulActions.append(liAction);
				}
				parentLi.append(ulActions);
				for (d in Cls.draggable_action.from(ulActions)) {
					Utils.addListener(listeners, d, 'dragstart', (_) -> onDragStart(d.dataset.action_id));
					Utils.addListener(listeners, d, 'dragover', onDragOver);
					Utils.addListener(listeners, d, 'dragleave', onDragLeave);
					Utils.addListener(listeners, d, 'drop', (e) -> onDrop(e, state));
				}
			}
			http.request();
		}

		parentLi.addEventListener('click', (event:Event) -> {
			Utils.stopPropagation(event);
			Utils.selectElement(parentLi);
			edit(state);
		});

		switch Cls.add_action_btn.firstFrom(parentLi) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					Utils.stopPropagation(event);

					App.updateActionDescriptors().then(_ -> {
						var actionDescriptors = App.editorData.actionDescriptors;
						Id.new_action_description.get().textContent = null;
						var emptyOption = [{value: 0, text: ''}];
						Utils.fillSelectElement(Id.actions_select.as(SelectElement), emptyOption.concat([
							for (i in 0...actionDescriptors.length)
								{value: i, text: actionDescriptors[i].name}
						]));
						Utils.clearElement(Id.action_presets.get());
						var selListener = [];
						Utils.addListener(selListener, Id.actions_select.get(), 'change', (_) -> {
							var selectedActionIndex = Id.actions_select.as(SelectElement).selectedIndex;
							if (selectedActionIndex == 0)
								return;
							var actionDescriptor = actionDescriptors[selectedActionIndex - 1];
							var actionPresets = actionDescriptor.presets;
							Id.new_action_description.get().textContent = actionDescriptor.description;
							if (actionPresets != null && actionPresets.length != 0) {
								Id.action_presets.as(SelectElement).disabled = false;
								Utils.fillSelectElement(Id.action_presets.as(SelectElement),
									emptyOption.concat([for (i in 0...actionPresets.length) {value: i + 1, text: actionPresets[i].name}]));
							} else {
								Id.action_presets.as(SelectElement).disabled = true;
							}
						});
						Dialog.show('::show_title_new_action::', Id.new_action.get(), () -> {
							return new js.lib.Promise((resolve, reject) -> {
								var selectedActionIndex = Id.actions_select.as(SelectElement).selectedIndex;
								if (selectedActionIndex == 0) {
									resolve(false);
									return;
								}

								var actionDescriptor = actionDescriptors[selectedActionIndex - 1];
								var actionName = actionDescriptor.name;

								function addAction(props:Any) {
									if (state.actions == null) {
										state.actions = [];
									}

									var action = {
										name: actionName,
										enabled: true,
										props: props
									};
									state.actions.push(action);

									Utils.removeListeners(selListener);

									App.dirtyData = true;
									DirEditor.refresh();
									ItemEditor.refresh();
									FixedEditor.show();
									ActionEditor.edit(action);
									resolve(true);
								}

								var actionPresets = actionDescriptor.presets;
								if (actionPresets != null && actionPresets.length != 0) {
									var selectedPresetIndex = Id.action_presets.as(SelectElement).selectedIndex;
									if (selectedPresetIndex > 0) {
										var preset = actionPresets[selectedPresetIndex - 1];
										var actionProps = preset.props;
										if (actionProps == null) {
											js.Browser.alert(Utils.formatString('::alert_preset_missing_mandatory_prop::', [preset.name]));
											resolve(false);
											return;
										}

										PresetEditor.edit(actionName, preset).then(newProps -> {
											addAction(newProps);
										}).catchError(e -> trace(e));
										return;
									}
								}

								var actionDefaultProps = {};
								var defValue;
								if (actionDescriptor.props != null) {
									for (p in actionDescriptor.props) {
										defValue = (p.defaultValue == null) ? null : p.defaultValue.replace('"', '').replace("'", '');
										if (p.type != null && p.type == PropEditorFieldType.boolean)
											Reflect.setField(actionDefaultProps, p.name, defValue == 'true');
										else
											Reflect.setField(actionDefaultProps, p.name, defValue);
									}
								}

								addAction(actionDefaultProps);
							});
						}, () -> {
							Utils.removeListeners(selListener);
						});
					}).catchError(error -> trace(error));
				});
			case None:
				trace('No [${Cls.add_action_btn.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
		}

		switch Cls.delete_btn.firstFrom(parentLi) {
			case Some(v):
				Utils.addListener(listeners, v, 'click', (event) -> {
					event.stopImmediatePropagation();

					trace('removing ${state.id} state');
					if (js.Browser.window.confirm(Utils.formatString('::confirm_remove_state::', [state.text]))) {
						for (i in App.getAllItems()) {
							switch i.kind {
								case States(_, list):
									trace('${i.id} ezabatzen: ${list.length}');
									for (sind in 0...list.length) {
										// trace('state id -> ${list[sind].id}');
										if (list[sind].id == state.id) {
											trace('removing ${state.id} state');
											list.remove(state);
											App.dirtyData = true;
											DirEditor.refresh();
											ItemEditor.refresh();
											FixedEditor.show();
										}
									}
								default:
							}
						}
					}
				});
			case None:
				trace('No [${Cls.delete_btn.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
		}
		return parentLi;
	}

	static function onDragStart(actionId:String) {
		draggingActionIndex = Std.parseInt(actionId);
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

	static function onDrop(e:Event, state:CoreState) {
		for (d in Cls.drag_over.get())
			d.classList.remove(Cls.drag_over);
		var targetActionIndex = Std.parseInt(cast(e.currentTarget, Element).dataset.action_id);

		var actionToMove = state.actions.splice(draggingActionIndex, 1)[0];

		if (actionToMove != null) {
			state.actions.insert(targetActionIndex, actionToMove);
			App.dirtyData = true;
			DirEditor.refresh();
			ItemEditor.refresh();
			FixedEditor.show();
		}
	}

	public static function refresh() {
		edit(editingState);
	}

	public static function edit(state:CoreState) {
		if (state == null) {
			Id.state_properties.get().classList.add(Cls.hidden);
			return;
		}

		ActionEditor.hide();

		Utils.removeListeners(listeners);
		editingState = state;

		Id.state_properties.get().classList.remove(Cls.hidden);

		Id.text.as(InputElement).value = editingState.text;
		var textColor = editingState.textColor;
		Id.text_color.as(InputElement).value = textColor == null ? '' : '#' + textColor.substr(2);
		var bgColor = editingState.bgColor;
		Id.bg_color.as(InputElement).value = bgColor == null ? '' : '#' + bgColor.substr(2);
		var textSize = editingState.textSize;
		Id.text_size.as(InputElement).value = Std.string(textSize == null ? App.editorData.layout.textSize : textSize);
		var textPosition = editingState.textPosition;
		if (textPosition == null)
			textPosition = TextPosition.bottom;
		Id.text_position.as(SelectElement).value = textPosition;

		Utils.fillSelectElement(Id.icons.as(SelectElement), [for (i in 0...App.icons.length) {value: i, text: App.icons[i].name}]);

		if (editingState.icon != null && editingState.icon != '') {
			switch Utils.getIconIndexByName(editingState.icon) {
				case Some(index):
					Id.icons.as(SelectElement).selectedIndex = index;
					setIconPreview(App.icons[index]);
				case None:
			};
		} else {
			setIconPreview(null);
		}

		Utils.addListener(listeners, Id.text.get(), 'change', onTextChange);
		Utils.addListener(listeners, Id.text_color.get(), 'change', onTextColorChange);
		Utils.addListener(listeners, Id.bg_color.get(), 'change', onBgColorChange);
		Utils.addListener(listeners, Id.text_size.get(), 'change', onTextSizeChange);
		Utils.addListener(listeners, Id.text_position.get(), 'change', onTextPositionChange);
		Utils.addListener(listeners, Id.icons.get(), 'change', onIconChange);
	}

	public static function hide() {
		editingState = null;
		Utils.removeListeners(listeners);
		Id.state_properties.get().classList.add(Cls.hidden);
	}

	static function setIconPreview(selectedIcon:App.IconData) {
		if (selectedIcon != null && selectedIcon.name != '') {
			Id.icon_preview.get().classList.remove(Cls.hidden);
			Id.icon_preview.as(ImageElement).src = Utils.defaultBase64Prefix(selectedIcon.base64);
		} else {
			Id.icon_preview.get().classList.add(Cls.hidden);
		}
	}

	static function onIconChange(_) {
		if (editingState == null)
			return;
		var selectedIcon = App.icons[Id.icons.as(SelectElement).selectedIndex];
		editingState.icon = selectedIcon.name;
		setIconPreview(selectedIcon);
		updateState();
	}

	static function onTextChange(_) {
		if (editingState == null)
			return;
		editingState.text = Id.text.as(InputElement).value;
		updateState();
	}

	static function onTextColorChange(_) {
		if (editingState == null)
			return;
		editingState.textColor = 'ff' + Id.text_color.as(InputElement).value.substr(1);
		updateState();
	}

	static function onBgColorChange(_) {
		if (editingState == null)
			return;
		editingState.bgColor = 'ff' + Id.bg_color.as(InputElement).value.substr(1);
		updateState();
	}

	static function onTextSizeChange(_) {
		if (editingState == null)
			return;
		editingState.textSize = Std.parseInt(Id.text_size.as(InputElement).value);
		updateState();
	}

	static function onTextPositionChange(_) {
		if (editingState == null)
			return;
		editingState.textPosition = Id.text_position.as(SelectElement).value;
		updateState();
	}

	static function updateState() {
		if (editingState == null)
			return;
		for (i in App.getAllItems()) {
			switch i.kind {
				case null:
				case ChangeDir(toDir, state):
					if (state.id == editingState.id)
						i.kind = ChangeDir(toDir, editingState);
				case States(_, list):
					for (sind in 0...list.length) {
						if (list[sind].id == editingState.id)
							list[sind] = editingState;
					}
			}
		}

		App.dirtyData = true;
		DirEditor.refresh();
		ItemEditor.refresh();
		FixedEditor.show();
	}
}

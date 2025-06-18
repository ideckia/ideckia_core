import js.html.HtmlElement;
import js.html.UListElement;
import api.IdeckiaApi;
import api.internal.CoreApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.DivElement;
import js.html.Element;
import js.html.Event;
import js.html.InputElement;
import js.html.LIElement;
import js.html.SelectElement;
import js.html.SpanElement;

using StringTools;

class ActionEditor {
	static var editingAction:ActionDef;
	static var changeListeners:Array<{element:Element, changeListener:Event->Void}> = [];
	static var listeners:Array<Utils.Listener> = [];

	public static function show(action:ActionDef, actionStatus:ActionStatus, parentState:CoreState) {
		var li = Utils.cloneElement(Id.action_list_item_tpl.get(), LIElement);
		switch Tag.span.firstFrom(li) {
			case Some(v):
				v.innerText = '${action.name} [id=${action.id}]';
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}
		li.addEventListener('click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(li);
			edit(action);
		});

		var bgClass = Cls.unknown_bg;
		var markClass = Cls.unknown_mark;
		var message = null;
		if (actionStatus != null) {
			bgClass = switch actionStatus.code {
				case error:
					Cls.error_bg;
				case ok:
					Cls.success_bg;
				default:
					Cls.unknown_bg;
			}

			markClass = switch actionStatus.code {
				case error:
					Cls.error_mark;
				case ok:
					Cls.success_mark;
				default:
					Cls.unknown_mark;
			}
			if (actionStatus.message != null)
				message = actionStatus.message;
		}

		switch Cls.check_bg.firstFrom(li) {
			case Some(v):
				v.title = Utils.formatString('::title_action_status::', [bgClass.replace('-bg', '')]);
				if (message != null)
					v.title += ': $message';
				v.classList.add(bgClass);
			case None:
		}
		switch Cls.check_mark.firstFrom(li) {
			case Some(v):
				v.classList.add(markClass);
			case None:
		}
		switch Cls.enable_check.firstFromAs(li, InputElement) {
			case Some(v):
				v.checked = action.enabled;
				v.addEventListener('click', (event) -> {
					App.dirtyData = true;
					action.enabled = v.checked;
				});
			case None:
				trace('No [${Cls.enable_check.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}
		switch Cls.delete_btn.firstFrom(li) {
			case Some(v):
				Utils.addListener(listeners, v, 'click', (event) -> {
					Utils.stopPropagation(event);
					if (js.Browser.window.confirm(Utils.formatString('::confirm_remove_action::', [action.name]))) {
						parentState.actions.remove(action);
						App.dirtyData = true;
						DirEditor.refresh();
						ItemEditor.refresh();
						FixedEditor.show();
					}
				});
			case None:
				trace('No [${Cls.delete_btn.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}
		return li;
	}

	public static function refresh() {
		edit(editingAction);
	}

	public static function edit(action:ActionDef) {
		Utils.removeListeners(listeners);

		function handleDescriptor(actionDescriptor:ActionDescriptor) {
			Utils.clearElement(Id.action_props.get());
			editingAction = action;
			var fieldValue;
			Id.action_title.get().textContent = Utils.formatString('::text_content_action_props::', [actionDescriptor.name]);
			Utils.addListener(listeners, Id.props_to_clipboard_btn.get(), 'click', (_) -> {
				js.Browser.window.navigator.clipboard.writeText(haxe.Json.stringify(editingAction.props, null, '  '))
					.then(_ -> js.Browser.alert('::success_props_to_clipboard::'))
					.catchError(e -> js.Browser.alert(Utils.formatString('::error_props_to_clipboard::', [e])));
			});
			Id.action_description.get().textContent = actionDescriptor.description;
			Id.action_properties.get().classList.remove(Cls.hidden);
			for (div in createFromDescriptor(actionDescriptor)) {
				var propertyName = div.id;
				var valueInput:InputElement = cast div.querySelector(Cls.prop_value.selector());
				var possibleValuesSelect:SelectElement = cast div.querySelector(Cls.prop_possible_values.selector());
				var booleanValueInput:InputElement = cast div.querySelector(Cls.prop_bool_value.selector());
				var multiValuesDiv:DivElement = cast div.querySelector(Cls.prop_multi_values.selector());
				fieldValue = (Reflect.hasField(editingAction.props, propertyName)) ? Reflect.field(editingAction.props, propertyName) : '';
				var divDataType = div.dataset.prop_type;
				if (!valueInput.classList.contains(Cls.hidden)) {
					var isPrimitive = Utils.isPrimitiveTypeByName(divDataType);
					if (isPrimitive)
						valueInput.value = fieldValue;
					else
						valueInput.value = haxe.Json.stringify(fieldValue);

					Utils.addListener(listeners, valueInput, 'change', (_) -> {
						var value = valueInput.value;
						var propValue:Dynamic = (valueInput.type == 'number') ? Std.parseFloat(value) : (isPrimitive || value == '') ? value : haxe.Json.parse(value);
						Reflect.setField(editingAction.props, propertyName, propValue);
						App.dirtyData = true;
					});
				} else if (!possibleValuesSelect.classList.contains(Cls.hidden)) {
					var children = possibleValuesSelect.children;
					if (children != null)
						for (cind in 0...children.length)
							if (children.item(cind).textContent == fieldValue)
								possibleValuesSelect.selectedIndex = cind;

					Utils.addListener(listeners, possibleValuesSelect, 'change', (_) -> {
						Reflect.setField(editingAction.props, propertyName, children[possibleValuesSelect.selectedIndex].textContent);
						App.dirtyData = true;
					});
				} else if (!booleanValueInput.classList.contains(Cls.hidden)) {
					booleanValueInput.checked = Std.string(fieldValue) == 'true';
					Utils.addListener(listeners, booleanValueInput, 'change', (_) -> {
						Reflect.setField(editingAction.props, propertyName, booleanValueInput.checked);
						App.dirtyData = true;
					});
				} else if (!multiValuesDiv.classList.contains(Cls.hidden)) {
					var valuesArray:Array<Any> = cast fieldValue;
					switch Tag.ul.firstFrom(multiValuesDiv) {
						case Some(v):
							multiValuesDiv.removeChild(v);
						case None:
					}

					var ul = document.createUListElement();
					switch Cls.add_array_value.firstFrom(multiValuesDiv) {
						case Some(v):
							multiValuesDiv.insertBefore(ul, v);
						case None:
							multiValuesDiv.appendChild(ul);
					}
					var multiValuesType = multiValuesDiv.dataset.type;
					var isNumeric = Utils.isNumeric(multiValuesType);
					var isPrimitive = Utils.isPrimitiveTypeByName(multiValuesType);

					function updateValuesArray(ul:UListElement) {
						var newArray = [];
						for (ulChild in ul.children) {
							switch Tag.input.firstFrom(ulChild) {
								case Some(v):
									var value = cast(v, InputElement).value;
									var propValue:Dynamic = (isNumeric) ? Std.parseFloat(value) : (isPrimitive || value == '') ? value : haxe.Json.parse(value);
									newArray.push(propValue);
								case None:
							}
						}

						Reflect.setField(editingAction.props, propertyName, newArray);
						App.dirtyData = true;
					}

					inline function addArrayValue(value:Dynamic) {
						var li = Utils.cloneElement(Id.prop_multi_value_li_tpl.get(), LIElement);
						li.classList.remove(Cls.hidden);
						var liChild = document.createInputElement();
						if (isNumeric) {
							liChild.type = 'number';
						} else {
							liChild.type = 'text';
							liChild.setAttribute('list', Id.shared_vars_datalist);
						}
						if (value != null)
							liChild.value = (isPrimitive) ? value : haxe.Json.stringify(value);

						switch Cls.remove_value.firstFrom(li) {
							case Some(v):
								Utils.addListener(listeners, v, 'click', (_) -> {
									if (!js.Browser.window.confirm('::confirm_remove_value::'))
										return;

									ul.removeChild(li);
									updateValuesArray(ul);
								});
							case None:
						}
						Utils.addListener(listeners, liChild, 'change', (e) -> {
							updateValuesArray(ul);
						});
						li.insertBefore(liChild, li.children[0]);
						ul.appendChild(li);
					}

					switch Cls.add_array_value.firstFrom(multiValuesDiv) {
						case Some(v):
							Utils.addListener(listeners, v, 'click', (_) -> addArrayValue(null));
						case None:
					}

					if (valuesArray != null)
						for (value in valuesArray)
							addArrayValue(value);
				}

				Id.action_props.get().appendChild(div);
			}
		}

		if (action.id == null || action.id == new ActionId(-1)) {
			switch App.getActionDescriptorByName(action.name) {
				case None:
					trace('Descriptor not found for [${action.name}]');
				case Some(actionDescriptor):
					handleDescriptor(actionDescriptor);
			}
		} else {
			final port = js.Browser.location.port;
			var endpoint = Endpoint.actionDescriptorForId(action.id.toUInt());
			var http = new haxe.Http('http://localhost:$port/$endpoint');
			http.addHeader('Content-Type', 'application/json');
			http.onError = (e) -> {
				if (action.enabled)
					trace(Utils.formatString('::alert_error_action_desc::', [Std.string(action.id), e]));
				switch App.getActionDescriptorByName(action.name) {
					case None:
						trace('Descriptor not found for [${action.name}]');
					case Some(actionDescriptor):
						handleDescriptor(actionDescriptor);
				}
			};
			http.onData = (d) -> handleDescriptor(haxe.Json.parse(d));

			http.request();
		}
	}

	public static function hide() {
		editingAction = null;
		Utils.removeListeners(listeners);
		Id.action_properties.get().classList.add(Cls.hidden);
	}

	static function createFromDescriptor(actionDescriptor:ActionDescriptor) {
		if (actionDescriptor.props == null)
			return [];

		var div:DivElement,
			nameSpan:SpanElement,
			possibleValuesSelect:SelectElement,
			booleanValueInput:InputElement,
			multiValuesDiv:DivElement;
		var divs:Array<DivElement> = [];
		for (prop in actionDescriptor.props) {
			if (prop.isShared) {
				var sharedName = if (prop.sharedName == '' || prop.sharedName == null) {
					actionDescriptor.name + '.' + prop.name;
				} else {
					prop.sharedName;
				}
				var found = false;
				if (App.editorData.layout.sharedVars != null)
					for (sv in App.editorData.layout.sharedVars)
						if (sv.key == sharedName)
							found = true;

				if (!found) {
					var value = (prop.defaultValue == null) ? null : prop.defaultValue.replace('"', '').replace("'", '');
					App.updateSharedValues({
						key: sharedName,
						value: value
					});
				}

				Reflect.setField(editingAction.props, prop.name, '$' + sharedName);
			}

			div = Utils.cloneElement(Id.action_prop_tpl.get(), DivElement);
			div.classList.remove(Cls.hidden);
			div.id = prop.name;
			var divDataType = PropEditorFieldType.fromTypeName(prop.name, prop.type);
			div.dataset.prop_type = divDataType;
			nameSpan = cast div.querySelector(Cls.prop_name.selector());
			var valueInput = cast div.querySelector(Cls.prop_value.selector());
			possibleValuesSelect = cast div.querySelector(Cls.prop_possible_values.selector());
			booleanValueInput = cast div.querySelector(Cls.prop_bool_value.selector());
			multiValuesDiv = cast div.querySelector(Cls.prop_multi_values.selector());
			if (prop.possibleValues != null && prop.possibleValues.length != 0) {
				possibleValuesSelect.classList.remove(Cls.hidden);
				Utils.fillSelectElement(possibleValuesSelect, [
					for (i in 0...prop.possibleValues.length)
						{value: i, text: prop.possibleValues[i]}
				]);
			} else {
				if (divDataType == PropEditorFieldType.boolean) {
					booleanValueInput.classList.remove(Cls.hidden);
				} else if (divDataType.startsWith(PropEditorFieldType.listOf)) {
					multiValuesDiv.dataset.type = divDataType.substring(0, divDataType.length - 1).replace(PropEditorFieldType.listOf + '<', '');
					multiValuesDiv.classList.remove(Cls.hidden);
				} else if (divDataType == PropEditorFieldType.icon) {
					possibleValuesSelect.classList.remove(Cls.hidden);
					Utils.fillSelectElement(possibleValuesSelect, [
						for (i in 0...App.icons.length)
							{value: i, text: App.icons[i].name}
					]);
				} else {
					if (prop.isShared) {
						valueInput.setAttribute('list', Id.shared_vars_datalist);
					} else if (divDataType == PropEditorFieldType.number) {
						valueInput.type = 'number';
					} else if (divDataType == PropEditorFieldType.password) {
						valueInput.type = 'password';
						var showPassword:HtmlElement = cast div.querySelector(Cls.show_password.selector());
						showPassword.classList.remove(Cls.hidden);
						switch Tag.input.firstFrom(showPassword) {
							case Some(v):
								v.onclick = (_) -> valueInput.type = (valueInput.type == 'text') ? 'password' : 'text';
							case None:
						}
					}
					valueInput.classList.remove(Cls.hidden);
				}
			}
			nameSpan.innerText = prop.name;
			var tooltipText = Utils.formatString('::action_tooltip_name::', [prop.name]) + '\n';
			tooltipText += Utils.formatString('::action_tooltip_type::', [prop.type]) + '\n';
			tooltipText += Utils.formatString('::action_tooltip_default_value::', [prop.defaultValue]) + '\n';
			tooltipText += Utils.formatString('::action_tooltip_description::', [prop.description]) + '\n';
			nameSpan.title = tooltipText;
			divs.push(div);
			Id.action_props.as(DivElement).appendChild(div);
		}
		return divs;
	}
}

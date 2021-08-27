import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

// TODO: goal is to weave user touch input + system IME input to produce
//       a single text field value: text + selection + composing region.
//
//       I'm not sure this is truly needed. I think that I was originally
//       considering the composing region to be part of the "document" but
//       it may be just a transient UI concern, similar to the floating cursor
//       or auto-correct rectangle. Worth some further thought.
class TextFieldValueController extends AttributedTextEditingController {
  TextFieldValueController({
    AttributedText? text,
    TextSelection? selection,
    TextRange composingRegion = TextRange.empty,
  })  : _composingRegion = composingRegion,
        super(text: text, selection: selection);

  @override
  set text(AttributedText newText) {
    super.text = text;
    _sendToPlatform();
  }

  @override
  set selection(TextSelection newSelection) {
    super.selection = selection;
    _sendToPlatform();
  }

  TextRange _composingRegion;
  TextRange get composingRegion => _composingRegion;
  set composingRegion(TextRange newRange) {
    if (newRange == _composingRegion) {
      // No change. Return.
      return;
    }

    _composingRegion = newRange;

    _sendToPlatform();

    notifyListeners();
  }

  @override
  void updateTextAndSelection({
    required AttributedText text,
    required TextSelection selection,
  }) {
    if (text == this.text || selection == this.selection) {
      // No change.
      return;
    }

    super.updateTextAndSelection(text: text, selection: selection);

    _sendToPlatform();
  }

  void update({
    required AttributedText text,
    required TextSelection selection,
    required TextRange composingRegion,
  }) {
    if (text == this.text && selection == this.selection && composingRegion == _composingRegion) {
      // No change. Return.
      return;
    }

    this.text = text;
    this.selection = selection;
    this.composingRegion = composingRegion;

    _sendToPlatform();

    notifyListeners();
  }

  TextEditingValue get _value => TextEditingValue(
        text: text.text,
        selection: selection,
        composing: composingRegion,
      );

  TextInputConnection? _inputConnection;
  TextEditingValue? _latestPlatformValue;
  set platformDelegate(TextInputConnection? newInputConnection) {
    if (newInputConnection == _inputConnection) {
      return;
    }

    _inputConnection = newInputConnection;

    _sendToPlatform();
  }

  void _sendToPlatform() {
    if (_inputConnection != null && _inputConnection!.attached && _latestPlatformValue != _value) {
      _inputConnection!.setEditingState(_value);
    }
  }

  void onUpdateFromPlatform(TextEditingValue valueFromPlatform) {
    final didChangeCurrentValue = valueFromPlatform != _value;
    _latestPlatformValue = valueFromPlatform;

    if (didChangeCurrentValue) {
      notifyListeners();
    }
  }
}

typedef PlatformDelegate = void Function(TextEditingValue value);

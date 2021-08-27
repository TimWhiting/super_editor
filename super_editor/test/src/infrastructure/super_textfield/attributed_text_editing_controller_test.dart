import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '../_attributed_text_test_tools.dart';

void main() {
  // TODO: handle selection changes.

  group('AttributedTextEditingController', () {
    group('insert', () {
      test('into empty text', () {
        final controller = AttributedTextEditingController();
        controller.insert(newText: 'newtext', insertIndex: 0);

        expect(controller.text.text, equals('newtext'));
      });

      test('into empty text with caret', () {
        final controller = AttributedTextEditingController(
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.insert(newText: 'newtext', insertIndex: 0);

        expect(controller.text.text, equals('newtext'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 7)));
      });

      test('into start of existing text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: ':existing text'),
        );
        controller.insert(newText: 'newtext', insertIndex: 0);

        expect(controller.text.text, equals('newtext:existing text'));
      });

      test('into start of existing text with caret', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: ':existing text'),
          selection: const TextSelection.collapsed(offset: 1),
        );
        controller.insert(newText: 'newtext', insertIndex: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 8)));
      });

      test('into start of existing text with selection after insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: ':existing text'),
          selection: const TextSelection(
            baseOffset: 1,
            extentOffset: 9,
          ),
        );
        controller.insert(newText: 'newtext', insertIndex: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 8,
              extentOffset: 16,
            ),
          ),
        );
      });

      test('into start of existing text with selection at insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: ':existing text'),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 9,
          ),
        );
        controller.insert(newText: 'newtext', insertIndex: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 16,
            ),
          ),
        );
      });

      test('into end of existing text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:'),
        );
        controller.insert(newText: 'newtext', insertIndex: 14);

        expect(controller.text.text, equals('existing text:newtext'));
      });

      test('into end of existing text with caret', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:'),
          selection: const TextSelection.collapsed(offset: 9),
        );
        controller.insert(newText: 'newtext', insertIndex: 14);

        expect(controller.text.text, equals('existing text:newtext'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 9)));
      });

      test('into end of existing text with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:'),
          selection: const TextSelection(baseOffset: 0, extentOffset: 8),
        );
        controller.insert(newText: 'newtext', insertIndex: 14);

        expect(controller.text.text, equals('existing text:newtext'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 8,
            ),
          ),
        );
      });

      test('into middle of styled text', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            text: '[]:unstyled text',
            spans: AttributedSpans(
              attributions: [
                const SpanMarker(attribution: boldAttribution, offset: 0, markerType: SpanMarkerType.start),
                const SpanMarker(attribution: boldAttribution, offset: 2, markerType: SpanMarkerType.end),
              ],
            ),
          ),
        );
        controller.insert(newText: 'newtext', insertIndex: 1);

        expect(controller.text.text, equals('[newtext]:unstyled text'));
        ExpectedSpans([
          'bbbbbbbbb______________',
        ]).expectSpans(controller.text.spans);
      });

      test('into middle of text with caret at insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            text: '[]:existing text',
          ),
          selection: const TextSelection.collapsed(offset: 1),
        );
        controller.insert(newText: 'newtext', insertIndex: 1);

        expect(controller.text.text, equals('[newtext]:existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 8)));
      });

      test('into middle of text with selection around insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            text: '[]:existing text',
          ),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 2,
          ),
        );
        controller.insert(newText: 'newtext', insertIndex: 1);

        expect(controller.text.text, equals('[newtext]:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 9,
            ),
          ),
        );
      });

      test('into middle of text with selection after insertion', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(
            text: '[]:existing text',
          ),
          selection: const TextSelection(
            baseOffset: 3,
            extentOffset: 11,
          ),
        );
        controller.insert(newText: 'newtext', insertIndex: 1);

        expect(controller.text.text, equals('[newtext]:existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 10,
              extentOffset: 18,
            ),
          ),
        );
      });
    });

    group('replace', () {
      test('empty text with new text at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: ':existing text'),
        );
        controller.replace(newText: 'newtext', from: 0, to: 0);

        expect(controller.text.text, equals('newtext:existing text'));
      });

      test('empty text with new text at beginning with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: ':existing text'),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 1,
          ),
        );
        controller.replace(newText: 'newtext', from: 0, to: 0);

        expect(controller.text.text, equals('newtext:existing text'));
        expect(
          controller.selection,
          const TextSelection(
            baseOffset: 0,
            extentOffset: 8,
          ),
        );
      });

      test('text with empty text at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'deleteme:existing text'),
        );
        controller.replace(newText: '', from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
      });

      test('text at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'replaceme:existing text'),
        );
        controller.replace(newText: 'newtext', from: 0, to: 9);

        expect(controller.text.text, equals('newtext:existing text'));
      });

      test('text at end', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:replaceme'),
        );
        controller.replace(newText: 'newtext', from: 14, to: 23);

        expect(controller.text.text, equals('existing text:newtext'));
      });

      test('text in the middle', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: '[replaceme]'),
        );
        controller.replace(newText: 'newtext', from: 1, to: 10);

        expect(controller.text.text, equals('[newtext]'));
      });
    });

    group('delete', () {
      test('from beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'deleteme:existing text'),
        );
        controller.delete(from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
      });

      test('from beginning with caret', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'deleteme:existing text'),
          selection: const TextSelection.collapsed(offset: 8),
        );
        controller.delete(from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
        expect(controller.selection, equals(const TextSelection.collapsed(offset: 0)));
      });

      test('from beginning with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'deleteme:existing text'),
          selection: const TextSelection(
            baseOffset: 4,
            extentOffset: 17,
          ),
        );
        controller.delete(from: 0, to: 8);

        expect(controller.text.text, equals(':existing text'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 9,
            ),
          ),
        );
      });

      test('from end', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:deleteme'),
        );
        controller.delete(from: 14, to: 22);

        expect(controller.text.text, equals('existing text:'));
      });

      test('from end with caret', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:deleteme'),
          // Caret part of the way into the text that will be deleted.
          selection: const TextSelection.collapsed(offset: 18),
        );
        controller.delete(from: 14, to: 22);

        expect(controller.text.text, equals('existing text:'));
        expect(
          controller.selection,
          equals(
            const TextSelection.collapsed(offset: 14),
          ),
        );
      });

      test('from end with selection', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: 'existing text:deleteme'),
          // Selection that starts near the end of remaining text and
          // extends part way into text that's deleted.
          selection: const TextSelection(baseOffset: 11, extentOffset: 18),
        );
        controller.delete(from: 14, to: 22);

        expect(controller.text.text, equals('existing text:'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 11,
              extentOffset: 14,
            ),
          ),
        );
      });

      test('from middle', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: '[deleteme]'),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
      });

      test('from middle with crosscutting selection at beginning', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: '[deleteme]'),
          selection: const TextSelection(
            baseOffset: 0,
            extentOffset: 5,
          ),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 0,
              extentOffset: 1,
            ),
          ),
        );
      });

      test('from middle with partial selection in middle', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: '[deleteme]'),
          selection: const TextSelection(
            baseOffset: 3,
            extentOffset: 6,
          ),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(const TextSelection.collapsed(offset: 1)),
        );
      });

      test('from middle with crosscutting selection at end', () {
        final controller = AttributedTextEditingController(
          text: AttributedText(text: '[deleteme]'),
          selection: const TextSelection(
            baseOffset: 5,
            extentOffset: 10,
          ),
        );
        controller.delete(from: 1, to: 9);

        expect(controller.text.text, equals('[]'));
        expect(
          controller.selection,
          equals(
            const TextSelection(
              baseOffset: 1,
              extentOffset: 2,
            ),
          ),
        );
      });
    });

    test('set text', () {
      final text1 = AttributedText(text: 'text1');
      final text2 = AttributedText(text: 'text2');

      final controller = AttributedTextEditingController(text: text1);
      expect(controller.text, equals(text1));
      expect(text1.hasListeners, true);
      expect(text2.hasListeners, false);

      controller.text = text2;
      expect(controller.text, equals(text2));
      expect(text1.hasListeners, false);
      expect(text2.hasListeners, true);
    });
  });
}

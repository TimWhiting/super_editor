import 'dart:math';

import 'package:flutter/material.dart';
import 'package:super_editor/src/infrastructure/_listenable_builder.dart';
import 'package:super_editor/src/infrastructure/super_selectable_text.dart';
import 'package:super_editor/src/infrastructure/super_textfield/super_textfield.dart';

import '_handles.dart';
import '_magnifier.dart';
import '_toolbar.dart';

/// Overlay editing controls for an iOS-style text field.
///
/// [IOSEditingControls] is intended to be displayed in the app's
/// [Overlay] so that its controls appear on top of everything else
/// in the app.
///
/// The given [IOSEditingOverlayController] controls the presentation
/// of [IOSEditingControls]. Use the controller to show/hide the
/// iOS-style toolbar, magnifier, and expanded selection handles.
class IOSEditingControls extends StatefulWidget {
  const IOSEditingControls({
    Key? key,
    required this.editingController,
    required this.textFieldKey,
    required this.textContentKey,
    required this.textFieldLayerLink,
    required this.textContentLayerLink,
    required this.handleColor,
    this.showDebugPaint = false,
  }) : super(key: key);

  /// Controller that determines whether the toolbar,
  /// magnifier, and/or selection handles are visible in
  /// this [IOSEditingControls].
  final IOSEditingOverlayController editingController;

  /// [LayerLink] that is anchored to the text field's boundary.
  final LayerLink textFieldLayerLink;

  /// [GlobalKey] that references the overall text field, i.e.,
  /// the viewport that contains text that's (possibly) larger
  /// than the visible area.
  final GlobalKey textFieldKey;

  /// [LayerLink] that is anchored to the (possibly scrolling) content
  /// within the text field.
  final LayerLink textContentLayerLink;

  /// [GlobalKey] that references the [SuperSelectableTextState] within
  /// the text field.
  final GlobalKey<SuperSelectableTextState> textContentKey;

  /// The color of the selection handles.
  final Color handleColor;

  /// Whether to paint debug guides.
  final bool showDebugPaint;

  @override
  _IOSEditingControlsState createState() => _IOSEditingControlsState();
}

class _IOSEditingControlsState extends State<IOSEditingControls> {
  // These global keys are assigned to each draggable handle to
  // prevent a strange dragging issue.
  //
  // Without these keys, if the user drags into the auto-scroll area
  // of the text field for a period of time, we never receive a
  // "pan end" or "pan cancel" callback. I have no idea why this is
  // the case. These handles sit in an Overlay, so it's not as if they
  // suffered some conflict within a ScrollView. I tried many adjustments
  // to recover the end/cancel callbacks. Finally, I tried adding these
  // global keys based on a hunch that perhaps the gesture detector was
  // somehow getting switched out, or assigned to a different widget, and
  // that was somehow disrupting the callback series. For now, these keys
  // seem to solve the problem.
  final _upstreamHandleKey = GlobalKey();
  final _downstreamHandleKey = GlobalKey();

  bool _isDraggingBase = false;
  bool _isDraggingExtent = false;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onBasePanStart(DragStartDetails details) {
    print('_onBasePanStart');

    widget.editingController.hideToolbar();

    // TODO: autoscroll if near boundary

    setState(() {
      _isDraggingBase = true;
      _isDraggingExtent = false;
      _dragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onExtentPanStart(DragStartDetails details) {
    print('_onExtentPanStart');

    widget.editingController.hideToolbar();

    // TODO: autoscroll if near boundary

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = true;
      _dragOffset = (context.findRenderObject() as RenderBox).globalToLocal(details.globalPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final textBox = (widget.textContentKey.currentContext!.findRenderObject() as RenderBox);
    final localOffset = textBox.globalToLocal(details.globalPosition);
    final textLayout = widget.textContentKey.currentState!;
    if (_isDraggingBase) {
      widget.editingController.textController.selection = widget.editingController.textController.selection.copyWith(
        baseOffset: textLayout.getPositionNearestToOffset(localOffset).offset,
      );
    } else if (_isDraggingExtent) {
      widget.editingController.textController.selection = widget.editingController.textController.selection.copyWith(
        extentOffset: textLayout.getPositionNearestToOffset(localOffset).offset,
      );
    }

    // TODO: autoscroll if near boundary

    setState(() {
      _dragOffset = _dragOffset! + details.delta;
      widget.editingController.showMagnifier(_dragOffset!);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    print('_onPanEnd');
    _onHandleDragEnd();
  }

  void _onPanCancel() {
    print('_onPanCancel');
    _onHandleDragEnd();
  }

  void _onHandleDragEnd() {
    print('_onHandleDragEnd()');
    // TODO: stop auto-scrolling
    // TODO: ensure that extent is visible

    setState(() {
      _isDraggingBase = false;
      _isDraggingExtent = false;
      widget.editingController.hideMagnifier();

      if (!widget.editingController.textController.selection.isCollapsed) {
        widget.editingController.showToolbar();
      }
    });
  }

  Offset _textPositionToViewportOffset(TextPosition position) {
    final textOffset = widget.textContentKey.currentState!.getOffsetAtPosition(position);
    final globalOffset =
        (widget.textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(textOffset);
    return (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
  }

  Offset _textOffsetToViewportOffset(Offset textOffset) {
    final globalOffset =
        (widget.textContentKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(textOffset);
    return (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(globalOffset);
  }

  @override
  Widget build(BuildContext context) {
    final textFieldRenderObject = context.findRenderObject();
    if (textFieldRenderObject == null) {
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
      return const SizedBox();
    }

    return MultiListenableBuilder(
        listenables: {
          widget.editingController,
          widget.editingController.textController,
        },
        builder: (context) {
          print('Building overlay controls. Selection: ${widget.editingController.textController.selection}');
          return Stack(
            children: [
              // Build the base and extent draggable handles
              ..._buildDraggableOverlayHandles(),
              // Build the editing toolbar
              _buildToolbar(),
              // Build the focal point for the magnifier
              if (_isDraggingBase || _isDraggingExtent) _buildMagnifierFocalPoint(),
              // Build the magnifier
              if (widget.editingController.isMagnifierVisible) _buildMagnifier(),
            ],
          );
        });
  }

  Widget _buildToolbar() {
    if (widget.editingController.textController.selection.extentOffset < 0) {
      return const SizedBox();
    }

    if (!widget.editingController.isToolbarVisible) {
      return const SizedBox();
    }

    const toolbarGap = 24.0;
    Offset toolbarTopAnchor;
    Offset toolbarBottomAnchor;

    if (widget.editingController.textController.selection.isCollapsed) {
      final extentOffsetInViewport =
          _textPositionToViewportOffset(widget.editingController.textController.selection.extent);
      print('Extent offset in viewport: $extentOffsetInViewport');
      final lineHeight = widget.textContentKey.currentState!
          .getLineHeightAtPosition(widget.editingController.textController.selection.extent);

      toolbarTopAnchor = extentOffsetInViewport - const Offset(0, toolbarGap);
      toolbarBottomAnchor = extentOffsetInViewport + Offset(0, lineHeight) + const Offset(0, toolbarGap);
      print('Collapsed top anchor offset in viewport: $toolbarTopAnchor');
    } else {
      final selectionBoxes =
          widget.textContentKey.currentState!.getBoxesForSelection(widget.editingController.textController.selection);
      Rect selectionBounds = selectionBoxes.first.toRect();
      for (int i = 1; i < selectionBoxes.length; ++i) {
        selectionBounds = selectionBounds.expandToInclude(selectionBoxes[i].toRect());
      }
      final selectionTopInText = selectionBounds.topCenter;
      final selectionTopInViewport = _textOffsetToViewportOffset(selectionTopInText);
      toolbarTopAnchor = selectionTopInViewport - const Offset(0, toolbarGap);

      final selectionBottomInText = selectionBounds.bottomCenter;
      final selectionBottomInViewport = _textOffsetToViewportOffset(selectionBottomInText);
      toolbarBottomAnchor = selectionBottomInViewport + const Offset(0, toolbarGap);
    }

    // The selection might start above the visible area in a scrollable
    // text field. In that case, we don't want the toolbar to sit more
    // than [toolbarGap] above the text field.
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      max(
        toolbarTopAnchor.dy,
        -toolbarGap,
      ),
    );

    // The selection might end below the visible area in a scrollable
    // text field. In that case, we don't want the toolbar to sit more
    // than [toolbarGap] below the text field.
    final viewportHeight = (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).size.height;
    toolbarTopAnchor = Offset(
      toolbarTopAnchor.dx,
      min(
        toolbarTopAnchor.dy,
        viewportHeight + toolbarGap,
      ),
    );

    print('Adjusted top anchor: $toolbarTopAnchor');

    final textFieldGlobalOffset =
        (widget.textFieldKey.currentContext!.findRenderObject() as RenderBox).localToGlobal(Offset.zero);

    return Stack(
      children: [
        // TODO: figure out why this approach works. Why isn't the text field's
        //       RenderBox offset stale when the keyboard opens or closes? Shouldn't
        //       we end up with the previous offset because no rebuild happens?
        //
        //       Dis-proven theory: CompositedTransformFollower's link causes a rebuild of its
        //       subtree whenever the linked transform changes.
        //
        //       Theory:
        //         - Keyboard only effects vertical offsets, so global x offset
        //           was never at risk
        //         - The global y offset isn't used in the calculation at all
        //         - If this same approach were used in a situation where the
        //           distance between the left edge of the available space and the
        //           text field changed, I think it would fail.
        CompositedTransformFollower(
          link: widget.textFieldLayerLink,
          child: CustomSingleChildLayout(
            delegate: _ToolbarPositionDelegate(
              textFieldGlobalOffset: textFieldGlobalOffset,
              desiredTopAnchorInTextField: toolbarTopAnchor,
              desiredBottomAnchorInTextField: toolbarBottomAnchor,
            ),
            child: IgnorePointer(
              ignoring: !widget.editingController.isToolbarVisible,
              child: AnimatedOpacity(
                opacity: widget.editingController.isToolbarVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: IOSTextfieldToolbar(
                  onCutPressed: () {},
                  onCopyPressed: () {},
                  onPastePressed: () {},
                  onSharePressed: () {},
                  onLookUpPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDraggableOverlayHandles() {
    if (widget.editingController.textController.selection.extentOffset < 0) {
      print('No extent -> no drag handles');
      // There is no selection. Draw nothing.
      return [];
    }

    if (widget.editingController.textController.selection.isCollapsed && !_isDraggingBase && !_isDraggingExtent) {
      print('No handle drag mode -> no drag handles');
      // iOS does not display a drag handle when the selection is collapsed.
      return [];
    }

    // The selection is expanded. Draw 2 drag handles.
    final baseCaretOffsetInViewport =
        _textPositionToViewportOffset(widget.editingController.textController.selection.base);
    final baseLineHeight = widget.textContentKey.currentState!
        .getLineHeightAtPosition(widget.editingController.textController.selection.base);

    final extentCaretOffsetInViewport =
        _textPositionToViewportOffset(widget.editingController.textController.selection.extent);
    final extentLineHeight = widget.textContentKey.currentState!
        .getLineHeightAtPosition(widget.editingController.textController.selection.extent);

    if (baseLineHeight == 0 || extentLineHeight == 0) {
      print('No height info -> no drag handles');
      // A line height of zero indicates that the text isn't laid out yet.
      // Schedule a rebuild to give the text a frame to layout.
      _scheduleRebuildBecauseTextIsNotLaidOutYet();
      return [];
    }

    // TODO: handle the case with no text affinity and then query widget.selection!.affinity
    final selectionDirection = widget.editingController.textController.selection.extentOffset >=
            widget.editingController.textController.selection.baseOffset
        ? TextAffinity.downstream
        : TextAffinity.upstream;

    // TODO: handle RTL text orientation
    final upstreamCaretOffset =
        selectionDirection == TextAffinity.downstream ? baseCaretOffsetInViewport : extentCaretOffsetInViewport;

    final downstreamCaretOffset =
        selectionDirection == TextAffinity.downstream ? extentCaretOffsetInViewport : baseCaretOffsetInViewport;

    // TODO: the following behavior checks if the handle visually overlaps
    //       the visible text box at all, and then hides the handle if it
    //       doesn't. Change this logic to instead get the bounding box around
    //       the first character in the selection and see if that character is
    //       at least partially visible. We should do this because at the moment
    //       the handle shows itself when its an entire line above or below the
    //       visible area.
    bool showBaseHandle = false;
    bool showExtentHandle = false;
    if (widget.textContentLayerLink.leader != null) {
      final textFieldBox = widget.textFieldKey.currentContext!.findRenderObject() as RenderBox;
      final textFieldRect = Offset.zero & textFieldBox.size;

      const estimatedHandleVisualSize = Size(24, 24);

      final estimatedBaseHandleRect = upstreamCaretOffset & estimatedHandleVisualSize;

      final estimatedExtentHandleRect = downstreamCaretOffset & estimatedHandleVisualSize;

      showBaseHandle = _isDraggingBase || textFieldRect.overlaps(estimatedBaseHandleRect);
      showExtentHandle = _isDraggingExtent || textFieldRect.overlaps(estimatedExtentHandleRect);
    }

    return [
      if (showBaseHandle)
        // Left-bounding handle touch target
        _buildHandle(
          handleKey: _upstreamHandleKey,
          followerOffset: Offset(upstreamCaretOffset.dx, upstreamCaretOffset.dy),
          onPanStart: selectionDirection == TextAffinity.downstream ? _onBasePanStart : _onExtentPanStart,
          debugColor: Colors.green,
          baseLineHeight: baseLineHeight,
        ),
      if (showExtentHandle)
        // right-bounding handle touch target
        _buildHandle(
          handleKey: _downstreamHandleKey,
          followerOffset: Offset(downstreamCaretOffset.dx, downstreamCaretOffset.dy),
          onPanStart: selectionDirection == TextAffinity.downstream ? _onExtentPanStart : _onBasePanStart,
          debugColor: Colors.red,
          baseLineHeight: baseLineHeight,
        ),
    ];
  }

  Widget _buildHandle({
    required Key handleKey,
    required Offset followerOffset,
    required void Function(DragStartDetails) onPanStart,
    required double baseLineHeight,
    required Color debugColor,
  }) {
    return CompositedTransformFollower(
      key: handleKey,
      link: widget.textContentLayerLink,
      offset: followerOffset,
      child: Transform.translate(
        offset: const Offset(-12, -5),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: Container(
            width: 24,
            color: widget.showDebugPaint ? Colors.green : Colors.transparent,
            child: IOSTextFieldHandle.upstream(
              color: widget.handleColor,
              caretHeight: baseLineHeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMagnifierFocalPoint() {
    // When the user is dragging a handle in this overlay, we
    // are responsible for positioning the focal point for the
    // magnifier to follow. We do that here.
    return Positioned(
      left: _dragOffset!.dx,
      top: _dragOffset!.dy,
      child: CompositedTransformTarget(
        link: widget.editingController.magnifierFocalPoint,
        child: SizedBox(width: 1, height: 1),
      ),
    );
  }

  Widget _buildMagnifier() {
    // Display a magnifier that tracks a focal point.
    //
    // When the user is dragging an overlay handle, we also place
    // the LayerLink target.
    //
    // When some other interaction wants to show the magnifier, then
    // that other area of the widget tree is responsible for
    // positioning the LayerLink target.
    return Center(
      child: FollowingMagnifier(
        // layerLink: _magnifierLink,
        layerLink: widget.editingController.magnifierFocalPoint,
        aboveFingerGap: 72,
        magnifierDiameter: 72,
        magnifierScale: 2,
      ),
    );
  }

  void _scheduleRebuildBecauseTextIsNotLaidOutYet() {
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      if (mounted) {
        setState(() {
          // no-op. Rebuild this widget in the hopes that the selectable
          // text has gone through a layout pass.
        });
      }
    });
  }
}

class IOSEditingOverlayController with ChangeNotifier {
  IOSEditingOverlayController({
    required this.textController,
    required LayerLink magnifierFocalPoint,
  }) : _magnifierFocalPoint = magnifierFocalPoint;

  bool _isToolbarVisible = false;
  bool get isToolbarVisible => _isToolbarVisible;

  /// The [AttributedTextEditingController] controlling the text
  /// and selection within the text field with which this
  /// [IOSEditingOverlayController] is associated.
  ///
  /// The purpose of an [IOSEditingOverlayController] is to control
  /// the presentation of UI controls related to text editing. These
  /// controls don't make sense without some underlying text and
  /// selection. Those properties and behaviors are represented by
  /// this [textController].
  final AttributedTextEditingController textController;

  void toggleToolbar() {
    if (isToolbarVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  void showToolbar() {
    hideMagnifier();

    _isToolbarVisible = true;

    notifyListeners();
  }

  void hideToolbar() {
    _isToolbarVisible = false;
    notifyListeners();
  }

  final LayerLink _magnifierFocalPoint;
  LayerLink get magnifierFocalPoint => _magnifierFocalPoint;

  bool _isMagnifierVisible = false;
  bool get isMagnifierVisible => _isMagnifierVisible;

  void showMagnifier(Offset globalOffset) {
    hideToolbar();

    _isMagnifierVisible = true;

    notifyListeners();
  }

  void hideMagnifier() {
    _isMagnifierVisible = false;
    notifyListeners();
  }

  bool _areSelectionHandlesVisible = false;
  bool get areSelectionHandlesVisible => _areSelectionHandlesVisible;

  void showSelectionHandles() {
    _areSelectionHandlesVisible = true;
    notifyListeners();
  }

  void hideSelectionHandles() {
    _areSelectionHandlesVisible = false;
    notifyListeners();
  }
}

class _ToolbarPositionDelegate extends SingleChildLayoutDelegate {
  _ToolbarPositionDelegate({
    required this.textFieldGlobalOffset,
    required this.desiredTopAnchorInTextField,
    required this.desiredBottomAnchorInTextField,
  });

  final Offset textFieldGlobalOffset;
  final Offset desiredTopAnchorInTextField;
  final Offset desiredBottomAnchorInTextField;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsAboveTextField = (textFieldGlobalOffset.dy + desiredTopAnchorInTextField.dy) > 100;
    final desiredAnchor = fitsAboveTextField
        ? desiredTopAnchorInTextField
        : (desiredBottomAnchorInTextField + Offset(0, childSize.height));

    final desiredTopLeft = desiredAnchor - Offset(childSize.width / 2, childSize.height);

    double x = max(desiredTopLeft.dx, -textFieldGlobalOffset.dx);
    x = min(x, size.width - childSize.width - textFieldGlobalOffset.dx);

    final constrainedOffset = Offset(x, desiredTopLeft.dy);

    // print('ToolbarPositionDelegate:');
    // print(' - available space: $size');
    // print(' - child size: $childSize');
    // print(' - text field offset: $textFieldGlobalOffset');
    // print(' - ideal y-position: ${textFieldGlobalOffset.dy + desiredTopAnchorInTextField.dy}');
    // print(' - fits above text field: $fitsAboveTextField');
    // print(' - desired anchor: $desiredAnchor');
    // print(' - desired top left: $desiredTopLeft');
    // print(' - actual offset: $constrainedOffset');

    return constrainedOffset;
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) {
    return true;
  }
}
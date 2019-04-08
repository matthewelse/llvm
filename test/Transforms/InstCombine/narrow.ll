; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -instcombine -S | FileCheck %s

target datalayout = "n8:16:32:64"

; Eliminating the casts in this testcase (by narrowing the AND operation)
; allows instcombine to realize the function always returns false.

define i1 @test1(i32 %A, i32 %B) {
; CHECK-LABEL: @test1(
; CHECK-NEXT:    ret i1 false
;
  %C1 = icmp slt i32 %A, %B
  %ELIM1 = zext i1 %C1 to i32
  %C2 = icmp sgt i32 %A, %B
  %ELIM2 = zext i1 %C2 to i32
  %C3 = and i32 %ELIM1, %ELIM2
  %ELIM3 = trunc i32 %C3 to i1
  ret i1 %ELIM3
}

; The next 6 (3 logic ops * (scalar+vector)) tests show potential cases for narrowing a bitwise logic op.

define i32 @shrink_xor(i64 %a) {
; CHECK-LABEL: @shrink_xor(
; CHECK-NEXT:    [[TMP1:%.*]] = trunc i64 [[A:%.*]] to i32
; CHECK-NEXT:    [[TRUNC:%.*]] = xor i32 [[TMP1]], 1
; CHECK-NEXT:    ret i32 [[TRUNC]]
;
  %xor = xor i64 %a, 1
  %trunc = trunc i64 %xor to i32
  ret i32 %trunc
}

; Vectors (with splat constants) should get the same transform.

define <2 x i32> @shrink_xor_vec(<2 x i64> %a) {
; CHECK-LABEL: @shrink_xor_vec(
; CHECK-NEXT:    [[TMP1:%.*]] = trunc <2 x i64> [[A:%.*]] to <2 x i32>
; CHECK-NEXT:    [[TRUNC:%.*]] = xor <2 x i32> [[TMP1]], <i32 2, i32 2>
; CHECK-NEXT:    ret <2 x i32> [[TRUNC]]
;
  %xor = xor <2 x i64> %a, <i64 2, i64 2>
  %trunc = trunc <2 x i64> %xor to <2 x i32>
  ret <2 x i32> %trunc
}

; Source and dest types are not in the datalayout.

define i3 @shrink_or(i6 %a) {
; CHECK-LABEL: @shrink_or(
; CHECK-NEXT:    [[TMP1:%.*]] = trunc i6 [[A:%.*]] to i3
; CHECK-NEXT:    [[TRUNC:%.*]] = or i3 [[TMP1]], 1
; CHECK-NEXT:    ret i3 [[TRUNC]]
;
  %or = or i6 %a, 33
  %trunc = trunc i6 %or to i3
  ret i3 %trunc
}

; Vectors (with non-splat constants) should get the same transform.

define <2 x i8> @shrink_or_vec(<2 x i16> %a) {
; CHECK-LABEL: @shrink_or_vec(
; CHECK-NEXT:    [[TMP1:%.*]] = trunc <2 x i16> [[A:%.*]] to <2 x i8>
; CHECK-NEXT:    [[TRUNC:%.*]] = or <2 x i8> [[TMP1]], <i8 -1, i8 0>
; CHECK-NEXT:    ret <2 x i8> [[TRUNC]]
;
  %or = or <2 x i16> %a, <i16 -1, i16 256>
  %trunc = trunc <2 x i16> %or to <2 x i8>
  ret <2 x i8> %trunc
}

; We discriminate against weird types.

define i31 @shrink_and(i64 %a) {
; CHECK-LABEL: @shrink_and(
; CHECK-NEXT:    [[AND:%.*]] = and i64 [[A:%.*]], 42
; CHECK-NEXT:    [[TRUNC:%.*]] = trunc i64 [[AND]] to i31
; CHECK-NEXT:    ret i31 [[TRUNC]]
;
  %and = and i64 %a, 42
  %trunc = trunc i64 %and to i31
  ret i31 %trunc
}

; Chop the top of the constant(s) if needed.

define <2 x i32> @shrink_and_vec(<2 x i33> %a) {
; CHECK-LABEL: @shrink_and_vec(
; CHECK-NEXT:    [[TMP1:%.*]] = trunc <2 x i33> [[A:%.*]] to <2 x i32>
; CHECK-NEXT:    [[TRUNC:%.*]] = and <2 x i32> [[TMP1]], <i32 0, i32 6>
; CHECK-NEXT:    ret <2 x i32> [[TRUNC]]
;
  %and = and <2 x i33> %a, <i33 4294967296, i33 6>
  %trunc = trunc <2 x i33> %and to <2 x i32>
  ret <2 x i32> %trunc
}

; FIXME:
; This is based on an 'any_of' loop construct.
; By narrowing the phi and logic op, we simplify away the zext and the final icmp.

define i1 @searchArray1(i32 %needle, i32* %haystack) {
; CHECK-LABEL: @searchArray1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[INDVAR:%.*]] = phi i32 [ 0, [[ENTRY:%.*]] ], [ [[INDVAR_NEXT:%.*]], [[LOOP]] ]
; CHECK-NEXT:    [[FOUND:%.*]] = phi i8 [ 0, [[ENTRY]] ], [ [[OR:%.*]], [[LOOP]] ]
; CHECK-NEXT:    [[TMP0:%.*]] = sext i32 [[INDVAR]] to i64
; CHECK-NEXT:    [[IDX:%.*]] = getelementptr i32, i32* [[HAYSTACK:%.*]], i64 [[TMP0]]
; CHECK-NEXT:    [[LD:%.*]] = load i32, i32* [[IDX]], align 4
; CHECK-NEXT:    [[CMP1:%.*]] = icmp eq i32 [[LD]], [[NEEDLE:%.*]]
; CHECK-NEXT:    [[ZEXT:%.*]] = zext i1 [[CMP1]] to i8
; CHECK-NEXT:    [[OR]] = or i8 [[FOUND]], [[ZEXT]]
; CHECK-NEXT:    [[INDVAR_NEXT]] = add i32 [[INDVAR]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i32 [[INDVAR_NEXT]], 1000
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[EXIT:%.*]], label [[LOOP]]
; CHECK:       exit:
; CHECK-NEXT:    [[TOBOOL:%.*]] = icmp ne i8 [[OR]], 0
; CHECK-NEXT:    ret i1 [[TOBOOL]]
;
entry:
  br label %loop

loop:
  %indvar = phi i32 [ 0, %entry ], [ %indvar.next, %loop ]
  %found = phi i8 [ 0, %entry ], [ %or, %loop ]
  %idx = getelementptr i32, i32* %haystack, i32 %indvar
  %ld = load i32, i32* %idx
  %cmp1 = icmp eq i32 %ld, %needle
  %zext = zext i1 %cmp1 to i8
  %or = or i8 %found, %zext
  %indvar.next = add i32 %indvar, 1
  %exitcond = icmp eq i32 %indvar.next, 1000
  br i1 %exitcond, label %exit, label %loop

exit:
  %tobool = icmp ne i8 %or, 0
  ret i1 %tobool
}

; FIXME:
; This is based on an 'all_of' loop construct.
; By narrowing the phi and logic op, we simplify away the zext and the final icmp.

define i1 @searchArray2(i32 %hay, i32* %haystack) {
; CHECK-LABEL: @searchArray2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[INDVAR:%.*]] = phi i64 [ 0, [[ENTRY:%.*]] ], [ [[INDVAR_NEXT:%.*]], [[LOOP]] ]
; CHECK-NEXT:    [[FOUND:%.*]] = phi i8 [ 1, [[ENTRY]] ], [ [[AND:%.*]], [[LOOP]] ]
; CHECK-NEXT:    [[IDX:%.*]] = getelementptr i32, i32* [[HAYSTACK:%.*]], i64 [[INDVAR]]
; CHECK-NEXT:    [[LD:%.*]] = load i32, i32* [[IDX]], align 4
; CHECK-NEXT:    [[CMP1:%.*]] = icmp eq i32 [[LD]], [[HAY:%.*]]
; CHECK-NEXT:    [[ZEXT:%.*]] = zext i1 [[CMP1]] to i8
; CHECK-NEXT:    [[AND]] = and i8 [[FOUND]], [[ZEXT]]
; CHECK-NEXT:    [[INDVAR_NEXT]] = add i64 [[INDVAR]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp eq i64 [[INDVAR_NEXT]], 1000
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[EXIT:%.*]], label [[LOOP]]
; CHECK:       exit:
; CHECK-NEXT:    [[TOBOOL:%.*]] = icmp ne i8 [[AND]], 0
; CHECK-NEXT:    ret i1 [[TOBOOL]]
;
entry:
  br label %loop

loop:
  %indvar = phi i64 [ 0, %entry ], [ %indvar.next, %loop ]
  %found = phi i8 [ 1, %entry ], [ %and, %loop ]
  %idx = getelementptr i32, i32* %haystack, i64 %indvar
  %ld = load i32, i32* %idx
  %cmp1 = icmp eq i32 %ld, %hay
  %zext = zext i1 %cmp1 to i8
  %and = and i8 %found, %zext
  %indvar.next = add i64 %indvar, 1
  %exitcond = icmp eq i64 %indvar.next, 1000
  br i1 %exitcond, label %exit, label %loop

exit:
  %tobool = icmp ne i8 %and, 0
  ret i1 %tobool
}

; FIXME:
; Narrowing should work with an 'xor' and is not limited to bool types.

define i32 @shrinkLogicAndPhi1(i8 %x, i1 %cond) {
; CHECK-LABEL: @shrinkLogicAndPhi1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF:%.*]], label [[ENDIF:%.*]]
; CHECK:       if:
; CHECK-NEXT:    br label [[ENDIF]]
; CHECK:       endif:
; CHECK-NEXT:    [[PHI:%.*]] = phi i32 [ 21, [[ENTRY:%.*]] ], [ 33, [[IF]] ]
; CHECK-NEXT:    [[ZEXT:%.*]] = zext i8 [[X:%.*]] to i32
; CHECK-NEXT:    [[LOGIC:%.*]] = xor i32 [[PHI]], [[ZEXT]]
; CHECK-NEXT:    ret i32 [[LOGIC]]
;
entry:
  br i1 %cond, label %if, label %endif
if:
  br label %endif
endif:
  %phi = phi i32 [ 21, %entry], [ 33, %if ]
  %zext = zext i8 %x to i32
  %logic = xor i32 %phi, %zext
  ret i32 %logic
}

; FIXME:
; Narrowing should work with an 'xor' and is not limited to bool types.
; Test that commuting the xor operands does not inhibit optimization.

define i32 @shrinkLogicAndPhi2(i8 %x, i1 %cond) {
; CHECK-LABEL: @shrinkLogicAndPhi2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 [[COND:%.*]], label [[IF:%.*]], label [[ENDIF:%.*]]
; CHECK:       if:
; CHECK-NEXT:    br label [[ENDIF]]
; CHECK:       endif:
; CHECK-NEXT:    [[PHI:%.*]] = phi i32 [ 21, [[ENTRY:%.*]] ], [ 33, [[IF]] ]
; CHECK-NEXT:    [[ZEXT:%.*]] = zext i8 [[X:%.*]] to i32
; CHECK-NEXT:    [[LOGIC:%.*]] = xor i32 [[PHI]], [[ZEXT]]
; CHECK-NEXT:    ret i32 [[LOGIC]]
;
entry:
  br i1 %cond, label %if, label %endif
if:
  br label %endif
endif:
  %phi = phi i32 [ 21, %entry], [ 33, %if ]
  %zext = zext i8 %x to i32
  %logic = xor i32 %zext, %phi
  ret i32 %logic
}


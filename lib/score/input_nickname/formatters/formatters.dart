import 'package:flutter/services.dart';
import 'package:moovz_dash/score/input_nickname/nickname_rules.dart';

List<TextInputFormatter> nicknameInputFormatters() {
  return [FilteringTextInputFormatter.allow(nicknameAllowedCharacterRegex)];
}

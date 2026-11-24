const nicknameMinLength = 3;
const nicknameMaxLength = 12;

final nicknameAllowedCharacterRegex = RegExp('[a-zA-Z0-9_]');

final nicknameRegex = RegExp(
  '^[a-zA-Z0-9_]{$nicknameMinLength,$nicknameMaxLength}\$',
);

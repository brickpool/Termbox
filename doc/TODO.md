# TO DO

## Unicode Support

- create WriteConsoleOutputCharacterW instead of using 
  Win32::Console::_WriteConsoleOutputCharacter
- create FillConsoleOutputCharacterW instead of using 
  Win32::Console::_FillConsoleOutputCharacter
- Recommendation of Unicode::EastAsianWidth::Detect for Win32 implementation

## XS-Modul

- Win32::API calls, e.g. WriteConsoleOutputW

## Legacy support
- termbox2 compatible color indexing for the legacy implementation
- providing TB_BRIGHT, TB_HI_BLACK
- providing TB_STRIKEOUT, TB_UNDERLINE_2, TB_OVERLINE

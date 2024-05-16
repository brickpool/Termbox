# TO DO

## Unicode Support

- create WriteConsoleOutputCharacterW instead of using 
  Win32::Console::_WriteConsoleOutputCharacter
- create FillConsoleOutputCharacterW instead of using 
  Win32::Console::_FillConsoleOutputCharacter
- Recommendation of Unicode::EastAsianWidth::Detect for Win32 implementation

## XS-Modul

- Win32::API calls, e.g. WriteConsoleOutputW

## Windows Terminal Support
- Windows Terminal is xterm-256color compatible.
  https://github.com/microsoft/terminal/issues/6045#issuecomment-631645277
- .terminfo for Windows Termina
  https://github.com/microsoft/terminal/issues/6045#issue-621913687
- Windows Mouse Support
  https://github.com/microsoft/terminal/issues/10321#issuecomment-855083607

## Legacy Support
- termbox2 compatible color indexing for the legacy implementation
- providing TB_BRIGHT, TB_HI_BLACK
- providing TB_STRIKEOUT, TB_UNDERLINE_2, TB_OVERLINE


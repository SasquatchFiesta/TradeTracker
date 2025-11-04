# TradeTracker

A World of Warcraft 3.3.5 addon that automatically tracks daily profession cooldowns across all your characters.

## Commands

- `/tt` or `/tradetracker` - Display cooldown status for all characters on current realm
- `/tt scan` - Manually scan for active cooldowns
- `/tt clear` - Clear all cooldowns for the current character
- `/tt debug` - Toggle debug mode (shows spell IDs when casting) (include debug output in https://github.com/SasquatchFiesta/TradeTracker/issues if having issues)
- 

### Finding Spell IDs (please report mismatched, missing, or inacurate spells and their CDs at https://github.com/SasquatchFiesta/TradeTracker/issues)
If you need to add a new cooldown or verify a spell ID:
1. Type `/tt debug` to enable debug mode
2. Cast the profession spell
3. The addon will display the spell ID in chat
4. Type `/tt debug` again to disable debug mode


## Version History

### v1.0 (Initial Release)
- Automatic cooldown detection
- Multi-character tracking
- Grouped display for similar transmutes
- Debug mode for finding spell IDs

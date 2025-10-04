# App Icon Implementation
*Technical details for icon assets across platforms*

## Character

```
ᕦ(ツ)ᕤ
```

**Character breakdown**:
- `ᕦ` - Left flexed arm (Unicode: U+1566, Canadian Aboriginal Syllabics)
- `(ツ)` - Happy face (Unicode: U+30C4, Katakana letter Tu)
- `ᕤ` - Right flexed arm (Unicode: U+1564, Canadian Aboriginal Syllabics)

## Visual Design

The icon presents:
- **Character**: ᕦ(ツ)ᕤ in black
- **Background**: Solid turquoise (#40E0D0)
- **Style**: Minimalist, bold, distinctive
- **Emotion**: Playful, energetic, friendly

## Icon Sizes

### iOS Requirements
- **App Store**: 1024×1024px (no alpha channel)
- **iPhone**: 180×180px (@3x), 120×120px (@2x), 60×60px (@1x)
- **iPad**: 167×167px (@2x), 152×152px (@2x)
- **Settings**: 87×87px (@3x), 58×58px (@2x), 29×29px (@1x)
- **Spotlight**: 120×120px (@3x), 80×80px (@2x), 40×40px (@1x)
- **Notifications**: 60×60px (@3x), 40×40px (@2x), 20×20px (@1x)

### Android Requirements
- **xxxhdpi**: 192×192px (4x)
- **xxhdpi**: 144×144px (3x)
- **xhdpi**: 96×96px (2x)
- **hdpi**: 72×72px (1.5x)
- **mdpi**: 48×48px (1x)
- **Google Play**: 512×512px

## Platform Integration

Icons are generated from a master design and placed in:
- **iOS**: `Assets.xcassets/AppIcon.appiconset/`
- **Android**: `res/mipmap-*/ic_launcher.png`

See platform-specific icon generation documentation:
- `miso/platforms/ios/icon-generation.md`
- `miso/platforms/eos/icon-generation.md`

## Branding Consistency

The nøøb character appears in:
1. **App Icon**: Device home screen (this feature)
2. **In-App Logo**: Main screen display
3. **Launch Screen**: App startup (future)
4. **Marketing**: App Store/Play Store screenshots

## Future Considerations

As the app matures, consider:
- **Professional Design**: Refined icon with proper composition
- **Background Variation**: Different colors or gradients
- **Adaptive Icons**: Android adaptive icon with foreground/background layers
- **Dark Mode**: Alternative icon for dark mode (iOS 18+)
- **Alternative Icons**: User-selectable app icons (iOS feature)

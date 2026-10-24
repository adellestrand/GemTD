"""Generate assets/graphics/ui_theme.tres - "slate & bronze" UI theme for GemTD (presentation only)."""
import sys

def c(h, a=1.0):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f'Color({r:.3f}, {g:.3f}, {b:.3f}, {a:.3f})'

# tokens
BG = '#121a22'; BAR = '#0e151b'; PANEL = '#18222b'; CARD = '#1d2832'; EDGE = '#33414d'
BRONZE = '#b8863b'; BRONZE_DIM = '#6e5430'; GOLD = '#e8c46a'
TEXT = '#ece3cc'; MUTED = '#8e9aa3'; FAINT = '#5d6a73'
BTN = '#26333f'; BTN_HOVER = '#2f3e4c'; BTN_PRESS = '#1b252f'; BTN_DIS = '#161e26'
PRIMARY = '#2e6a4c'; PRIMARY_HOVER = '#38805b'; PRIMARY_EDGE = '#5aa37b'; PRIMARY_SHADE = '#163522'
DANGER_EDGE = '#8a4038'

subs = []
def box(id_, bg, border=None, bw=(0, 0, 0, 0), radius=5, margin=(10, 8, 10, 8), shadow=None, bg_a=1.0):
    lines = [f'[sub_resource type="StyleBoxFlat" id="{id_}"]',
             f'content_margin_left = {margin[0]:.1f}', f'content_margin_top = {margin[1]:.1f}',
             f'content_margin_right = {margin[2]:.1f}', f'content_margin_bottom = {margin[3]:.1f}',
             f'bg_color = {c(bg, bg_a)}']
    if border:
        for side, w in zip(('left', 'top', 'right', 'bottom'), bw):
            if w: lines.append(f'border_width_{side} = {w}')
        lines.append(f'border_color = {c(border)}')
    if radius:
        for corner in ('top_left', 'top_right', 'bottom_right', 'bottom_left'):
            lines.append(f'corner_radius_{corner} = {radius}')
    if shadow:
        lines += [f'shadow_color = {c(shadow[0], shadow[1])}', f'shadow_size = {shadow[2]}', f'shadow_offset = Vector2(0, {shadow[3]})']
    subs.append('\n'.join(lines))
    return id_

def line_box(id_, col, thick=1, vertical=False):
    subs.append('\n'.join([f'[sub_resource type="StyleBoxLine" id="{id_}"]', f'color = {c(col)}', f'thickness = {thick}', f'vertical = {"true" if vertical else "false"}']))
    return id_

box('Panel', PANEL, EDGE, (1, 1, 1, 1), 6, (12, 12, 12, 12))
box('Card', CARD, BRONZE_DIM, (0, 2, 0, 0), 8, (14, 10, 14, 12), shadow=('#000000', .35, 10, 3), bg_a=.9)
box('Bar', BAR, BRONZE_DIM, (0, 0, 0, 1), 0, (14, 8, 14, 8), bg_a=.86)
box('Badge', '#0b1116', BRONZE_DIM, (1, 1, 1, 1), 12, (12, 4, 12, 5), bg_a=.92)
box('Chip', '#0f171e', '#2c3a46', (1, 1, 1, 1), 10, (9, 2, 9, 3))
box('Tile', '#131c24', '#27343f', (1, 1, 1, 1), 6, (10, 6, 10, 7))
box('Log', '#0e151b', EDGE, (1, 1, 1, 1), 6, (12, 7, 12, 8), bg_a=.88)
box('Portrait', '#0f171e', BRONZE_DIM, (2, 2, 2, 2), 8, (4, 4, 4, 4))
box('Hud', '#0b1116', '#2a3742', (1, 1, 1, 1), 10, (16, 5, 16, 6))
box('AccentNormal', '#352c1d', BRONZE_DIM, (1, 1, 1, 3), 6, (12, 8, 12, 8))
box('AccentHover', '#463a24', GOLD, (1, 1, 1, 3), 6, (12, 8, 12, 8))
box('AccentPressed', '#2a2216', GOLD, (1, 2, 1, 1), 6, (12, 9, 12, 7))
box('HeroNormal', PRIMARY, PRIMARY_SHADE, (1, 1, 1, 4), 8, (16, 12, 16, 12))
box('HeroHover', PRIMARY_HOVER, GOLD, (1, 1, 1, 4), 8, (16, 12, 16, 12))
box('HeroPressed', '#24543c', GOLD, (1, 2, 1, 2), 8, (16, 13, 16, 11))
box('HeroDisabled', BTN_DIS, '#222c35', (1, 1, 1, 1), 8, (16, 12, 16, 15))
box('Tray', '#120e0a', BRONZE_DIM, (2, 2, 2, 2), 10, (8, 8, 8, 8), shadow=('#000000', .45, 8, 3), bg_a=.94)
box('Normal', BTN, '#3c4b58', (1, 1, 1, 3), 5, (12, 7, 12, 7))
box('Hover', BTN_HOVER, BRONZE_DIM, (1, 1, 1, 3), 5, (12, 7, 12, 7))
box('Pressed', BTN_PRESS, BRONZE, (1, 2, 1, 1), 5, (12, 8, 12, 6))
box('Disabled', BTN_DIS, '#222c35', (1, 1, 1, 1), 5, (12, 7, 12, 9))
box('Focus', '#000000', GOLD, (1, 1, 1, 1), 5, (0, 0, 0, 0), bg_a=0)
box('PrimaryNormal', PRIMARY, PRIMARY_SHADE, (1, 1, 1, 3), 6, (14, 10, 14, 10))
box('PrimaryHover', PRIMARY_HOVER, GOLD, (1, 1, 1, 3), 6, (14, 10, 14, 10))
box('PrimaryPressed', '#24543c', GOLD, (1, 2, 1, 1), 6, (14, 11, 14, 9))
box('PrimaryDisabled', BTN_DIS, '#222c35', (1, 1, 1, 1), 6, (14, 10, 14, 12))
box('DangerNormal', BTN, DANGER_EDGE, (1, 1, 1, 3), 5, (12, 7, 12, 7))
box('ToolNormal', BTN, '#2c3944', (1, 1, 1, 1), 5, (10, 5, 10, 5), bg_a=.0)
box('ToolHover', BTN_HOVER, BRONZE_DIM, (1, 1, 1, 1), 5, (10, 5, 10, 5))
box('ToolPressed', BTN_PRESS, BRONZE, (1, 1, 1, 1), 5, (10, 5, 10, 5))
box('ToolDisabled', BTN_DIS, '#1c242c', (1, 1, 1, 1), 5, (10, 5, 10, 5), bg_a=0)
box('SlotNormal', '#1e1710', '#4a3920', (2, 2, 2, 2), 8, (4, 4, 4, 4))
box('SlotHover', '#2a2014', BRONZE, (2, 2, 2, 2), 8, (4, 4, 4, 4))
box('SlotPressed', '#33281a', GOLD, (2, 2, 2, 2), 8, (4, 4, 4, 4))
box('SlotDisabled', '#15110c', '#2e2416', (2, 2, 2, 2), 8, (4, 4, 4, 4))
box('ProgressBackground', '#0b1015', None, radius=3, margin=(0, 3, 0, 3))
box('ProgressFill', '#6fb58a', None, radius=3, margin=(0, 0, 0, 0))
box('BossFill', '#c4553f', None, radius=3, margin=(0, 0, 0, 0))
box('Tooltip', BAR, BRONZE_DIM, (1, 1, 1, 1), 6, (10, 8, 10, 8), shadow=('#000000', .5, 6, 2))
box('Popup', CARD, BRONZE_DIM, (1, 1, 1, 1), 6, (6, 6, 6, 6), shadow=('#000000', .5, 8, 3))
box('PopupHover', BTN_HOVER, None, radius=4, margin=(8, 4, 8, 4))
box('Window', PANEL, BRONZE_DIM, (2, 34, 2, 2), 8, (8, 8, 8, 8), shadow=('#000000', .6, 18, 6))
subs[-1] += '\nexpand_margin_left = 2.0\nexpand_margin_top = 34.0\nexpand_margin_right = 2.0\nexpand_margin_bottom = 2.0\nborder_color = ' + c('#2a2016')
box('Input', '#0e151b', EDGE, (1, 1, 1, 1), 5, (10, 7, 10, 7))
box('ScrollGrabber', '#3a4855', None, radius=4, margin=(0, 0, 0, 0))
box('ScrollGrabberHover', BRONZE_DIM, None, radius=4, margin=(0, 0, 0, 0))
box('ScrollTrack', '#000000', None, radius=4, margin=(4, 0, 4, 0), bg_a=0)
box('SliderTrack', '#2a3743', None, radius=3, margin=(0, 3, 0, 3))
box('SliderFill', BRONZE_DIM, None, radius=3, margin=(0, 3, 0, 3))
line_box('Separator', EDGE)

ext = ['[ext_resource type="FontFile" path="res://assets/fonts/Inter-Regular.otf" id="inter"]',
       '[ext_resource type="FontFile" path="res://assets/fonts/Inter-Medium.otf" id="inter_medium"]',
       '[ext_resource type="FontFile" path="res://assets/fonts/Inter-SemiBold.otf" id="inter_semibold"]',
       '[ext_resource type="FontFile" path="res://assets/fonts/Lora-Variable.ttf" id="lora"]']
subs.append('[sub_resource type="FontVariation" id="LoraSemi"]\nbase_font = ExtResource("lora")\nvariation_opentype = {2003265652: 600}')
subs.append('[sub_resource type="FontVariation" id="LoraBold"]\nbase_font = ExtResource("lora")\nvariation_opentype = {2003265652: 700}')
subs.append('[sub_resource type="FontVariation" id="Tabular"]\nbase_font = ExtResource("inter_semibold")\nopentype_features = {1953390957: 1}')  # 'tnum'

def btn(prefix, styles, font=TEXT, dis=FAINT):
    n, h, p, d = styles
    return [f'{prefix}/colors/font_color = {c(font)}', f'{prefix}/colors/font_hover_color = {c("#fff6dc")}',
            f'{prefix}/colors/font_pressed_color = {c(GOLD)}', f'{prefix}/colors/font_focus_color = {c(font)}',
            f'{prefix}/colors/font_disabled_color = {c(dis)}', f'{prefix}/colors/icon_disabled_color = {c("#ffffff", .35)}',
            f'{prefix}/styles/normal = SubResource("{n}")', f'{prefix}/styles/hover = SubResource("{h}")',
            f'{prefix}/styles/pressed = SubResource("{p}")', f'{prefix}/styles/hover_pressed = SubResource("{p}")',
            f'{prefix}/styles/disabled = SubResource("{d}")', f'{prefix}/styles/focus = SubResource("Focus")']

props = [
    'default_font = ExtResource("inter")', 'default_font_size = 15',
    *btn('Button', ('Normal', 'Hover', 'Pressed', 'Disabled')),
    'Button/fonts/font = ExtResource("inter_medium")',
    'PrimaryButton/base_type = &"Button"', *btn('PrimaryButton', ('PrimaryNormal', 'PrimaryHover', 'PrimaryPressed', 'PrimaryDisabled')),
    'PrimaryButton/fonts/font = ExtResource("inter_semibold")',
    'DangerButton/base_type = &"Button"', *btn('DangerButton', ('DangerNormal', 'Hover', 'Pressed', 'Disabled'), font='#e7c2b8'),
    'AccentButton/base_type = &"Button"', *btn('AccentButton', ('AccentNormal', 'AccentHover', 'AccentPressed', 'Disabled')),
    'AccentButton/fonts/font = ExtResource("inter_semibold")',
    'HeroButton/base_type = &"Button"', *btn('HeroButton', ('HeroNormal', 'HeroHover', 'HeroPressed', 'HeroDisabled')),
    'HeroButton/fonts/font = ExtResource("inter_semibold")', 'HeroButton/font_sizes/font_size = 16',
    'GhostDanger/base_type = &"Button"', *btn('GhostDanger', ('ToolNormal', 'ToolHover', 'ToolPressed', 'ToolDisabled'), font='#cf9086'),
    'ToolButton/base_type = &"Button"', *btn('ToolButton', ('ToolNormal', 'ToolHover', 'ToolPressed', 'ToolDisabled')),
    'ToolButton/font_sizes/font_size = 14',
    'SlotButton/base_type = &"Button"', *btn('SlotButton', ('SlotNormal', 'SlotHover', 'SlotPressed', 'SlotDisabled'), font=MUTED, dis='#4e4330'),
    'MenuButton/colors/font_color = ' + c(TEXT), 'MenuButton/styles/normal = SubResource("ToolNormal")',
    'MenuButton/styles/hover = SubResource("ToolHover")', 'MenuButton/styles/pressed = SubResource("ToolPressed")',
    'MenuButton/styles/focus = SubResource("Focus")', 'MenuButton/fonts/font = ExtResource("inter_medium")', 'MenuButton/font_sizes/font_size = 14',
    *btn('OptionButton', ('Normal', 'Hover', 'Pressed', 'Disabled')),
    f'Label/colors/font_color = {c("#d9d6c8")}',
    'SectionLabel/base_type = &"Label"', 'SectionLabel/fonts/font = SubResource("LoraSemi")', 'SectionLabel/font_sizes/font_size = 15',
    f'SectionLabel/colors/font_color = {c(BRONZE)}',
    'TitleLabel/base_type = &"Label"', 'TitleLabel/fonts/font = SubResource("LoraBold")', 'TitleLabel/font_sizes/font_size = 22',
    f'TitleLabel/colors/font_color = {c(TEXT)}',
    'BrandLabel/base_type = &"Label"', 'BrandLabel/fonts/font = SubResource("LoraBold")', 'BrandLabel/font_sizes/font_size = 24',
    f'BrandLabel/colors/font_color = {c(GOLD)}',
    'StatValue/base_type = &"Label"', 'StatValue/fonts/font = SubResource("Tabular")', 'StatValue/font_sizes/font_size = 19',
    f'StatValue/colors/font_color = {c(TEXT)}',
    'MutedLabel/base_type = &"Label"', 'MutedLabel/font_sizes/font_size = 12', f'MutedLabel/colors/font_color = {c(MUTED)}',
    'BadgeLabel/base_type = &"Label"', 'BadgeLabel/fonts/font = SubResource("LoraSemi")', 'BadgeLabel/font_sizes/font_size = 15',
    f'BadgeLabel/colors/font_color = {c(GOLD)}',
    f'LinkButton/colors/font_color = {c("#e4d4a4")}', f'LinkButton/colors/font_hover_color = {c("#fff0c8")}',
    f'LinkButton/colors/font_pressed_color = {c("#e4d4a4")}', f'LinkButton/colors/font_disabled_color = {c(FAINT)}',
    'PanelContainer/styles/panel = SubResource("Panel")',
    'Card/base_type = &"PanelContainer"', 'Card/styles/panel = SubResource("Card")',
    'Bar/base_type = &"PanelContainer"', 'Bar/styles/panel = SubResource("Bar")',
    'Badge/base_type = &"PanelContainer"', 'Badge/styles/panel = SubResource("Badge")',
    'Chip/base_type = &"PanelContainer"', 'Chip/styles/panel = SubResource("Chip")',
    'Tile/base_type = &"PanelContainer"', 'Tile/styles/panel = SubResource("Tile")',
    'Log/base_type = &"PanelContainer"', 'Log/styles/panel = SubResource("Log")',
    'Portrait/base_type = &"PanelContainer"', 'Portrait/styles/panel = SubResource("Portrait")',
    'Hud/base_type = &"PanelContainer"', 'Hud/styles/panel = SubResource("Hud")',
    'TileValue/base_type = &"Label"', 'TileValue/fonts/font = SubResource("Tabular")', 'TileValue/font_sizes/font_size = 18',
    f'TileValue/colors/font_color = {c(TEXT)}',
    'ChipLabel/base_type = &"Label"', 'ChipLabel/font_sizes/font_size = 12', f'ChipLabel/colors/font_color = {c("#cfd3c8")}',
    'Tray/base_type = &"PanelContainer"', 'Tray/styles/panel = SubResource("Tray")',
    'TabContainer/styles/panel = SubResource("Panel")', 'TextEdit/styles/normal = SubResource("Input")',
    'LineEdit/styles/normal = SubResource("Input")', 'LineEdit/styles/focus = SubResource("Focus")',
    'RichTextLabel/constants/table_h_separation = 18', 'RichTextLabel/constants/table_v_separation = 6',
    f'RichTextLabel/colors/default_color = {c("#d9d6c8")}',
    'VBoxContainer/constants/separation = 8', 'HBoxContainer/constants/separation = 10',
    'HSeparator/styles/separator = SubResource("Separator")', 'HSeparator/constants/separation = 12',
    'ProgressBar/styles/background = SubResource("ProgressBackground")', 'ProgressBar/styles/fill = SubResource("ProgressFill")',
    'BossHealth/base_type = &"ProgressBar"', 'BossHealth/styles/background = SubResource("ProgressBackground")',
    'BossHealth/styles/fill = SubResource("BossFill")',
    'TooltipPanel/styles/panel = SubResource("Tooltip")', f'TooltipLabel/colors/font_color = {c(TEXT)}',
    'PopupMenu/styles/panel = SubResource("Popup")', 'PopupMenu/styles/hover = SubResource("PopupHover")',
    f'PopupMenu/colors/font_color = {c(TEXT)}', f'PopupMenu/colors/font_hover_color = {c(GOLD)}',
    f'PopupMenu/colors/font_separator_color = {c(MUTED)}', 'PopupMenu/styles/separator = SubResource("Separator")',
    'Window/styles/embedded_border = SubResource("Window")', 'Window/styles/embedded_unfocused_border = SubResource("Window")',
    f'Window/colors/title_color = {c(GOLD)}', 'Window/fonts/title_font = SubResource("LoraSemi")', 'Window/font_sizes/title_font_size = 16', 'Window/constants/title_height = 34', 'Window/constants/close_h_offset = 22', 'Window/constants/close_v_offset = 23',
    'AcceptDialog/styles/panel = SubResource("Panel")',
    'VScrollBar/styles/scroll = SubResource("ScrollTrack")', 'VScrollBar/styles/grabber = SubResource("ScrollGrabber")',
    'VScrollBar/styles/grabber_highlight = SubResource("ScrollGrabberHover")', 'VScrollBar/styles/grabber_pressed = SubResource("ScrollGrabberHover")',
    'HSlider/styles/slider = SubResource("SliderTrack")', 'HSlider/styles/grabber_area = SubResource("SliderFill")',
    'HSlider/styles/grabber_area_highlight = SubResource("SliderFill")',
]
n = len(ext) + len(subs) + 1
out = [f'[gd_resource type="Theme" load_steps={n} format=3]', '', *[e for e in ext], '']
out += [s + '\n' for s in subs]
out += ['[resource]', *props, '']
open(sys.argv[1], 'w').write('\n'.join(out))
print('theme written', len(subs), 'styles')

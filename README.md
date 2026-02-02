# 📺 STCREATIVE-TV (tvfzf)

STCREATIVE-TV ek lightweight Bash script hai jo terminal ke andar Live TV channels stream karne ke liye `fzf` aur `mpv` ka use karti hai. Isme 140+ live channels aur real-time TV Guide (EPG) ka support hai.

## ✨ Features
- **140+ Live Channels**: News, Sports, Entertainment, aur bahut kuch.
- **EPG Support**: Abhi kaunsa show chal raha hai aur agla kaunsa hai, sab terminal mein dikhega.
- **Favorites**: Apne pasandida channels ko `Alt+F` daba kar save karein.
- **Categories**: Channels ko categories (Sports, News, etc.) ke hisab se browse karein.
- **Lightweight**: Bina kisi heavy GUI ke fast chalta hai.

## 🛠️ Requirements
Isko chalane ke liye aapke system mein ye tools hone chahiye:
- `fzf` (Menu interface ke liye)
- `curl` (Data fetch karne ke liye)
- `mpv` ya `vlc` (Video chalane ke liye)

### Installation (Linux/Termux/macOS)
```bash
# Ubuntu/Debian/Termux
sudo apt update && sudo apt install fzf mpv curl -y

# macOS
brew install fzf mpv curl

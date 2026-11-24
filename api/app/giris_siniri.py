"""Hatalı giriş sınırı: kısa sürede çok fazla yanlış şifre denenirse geçici kilit.

İki sayaç var:
- (e-posta, IP) başına: 15 dakikada 5 hata o ikiliyi 15 dakika kilitler. Kilit IP'ye
  bağlı olduğu için saldırgan, hesabın sahibini başka bir ağdan kilitleyemez.
- IP başına genel: 15 dakikada 20 hata, o IP'den bütün girişleri 15 dakika kilitler
  (farklı e-postalarla deneyerek sınırı aşmayı engeller). Başarılı giriş bu sayacı sıfırlamaz.

Sayaçlar bellekte tutulur (tek süreçli sunucu için yeterli; çok sunuculu kurulumda Redis
gibi paylaşılan bir depo gerekir). Süresi geçmiş sayaçlar her hatada budanır.
"""
import time
from threading import Lock

EN_FAZLA_HATA = 5
IP_EN_FAZLA_HATA = 20
PENCERE_SANIYE = 15 * 60  # hatalar bu süre içinde sayılır
KILIT_SANIYE = 15 * 60

_hatalar: dict[tuple[str, str], list[float]] = {}
_ip_hatalar: dict[str, list[float]] = {}
_kilit = Lock()


def _saat() -> float:
    return time.monotonic()


def _anahtar(email: str, ip: str) -> tuple[str, str]:
    return (email.strip().lower(), ip)


def _taze(denemeler: list[float], simdi: float) -> list[float]:
    return [t for t in denemeler if simdi - t < PENCERE_SANIYE]


def _kalan(denemeler: list[float], sinir: int, simdi: float) -> int:
    taze = _taze(denemeler, simdi)
    if len(taze) < sinir:
        return 0
    kalan = KILIT_SANIYE - (simdi - taze[-1])
    return int(kalan) + 1 if kalan > 0 else 0


def kalan_kilit_saniyesi(email: str, ip: str) -> int:
    """Kilitliyse kilidin bitmesine kalan saniye, değilse 0."""
    simdi = _saat()
    with _kilit:
        return max(
            _kalan(_hatalar.get(_anahtar(email, ip), []), EN_FAZLA_HATA, simdi),
            _kalan(_ip_hatalar.get(ip, []), IP_EN_FAZLA_HATA, simdi),
        )


def _buda(simdi: float) -> None:
    """Son hatası pencere + kilit süresinden eski sayaçları atar (bellek sınırsız büyümesin)."""
    esik = PENCERE_SANIYE + KILIT_SANIYE
    for sozluk in (_hatalar, _ip_hatalar):
        for anahtar in [a for a, d in sozluk.items() if not d or simdi - d[-1] > esik]:
            del sozluk[anahtar]


def hata_kaydet(email: str, ip: str) -> None:
    simdi = _saat()
    with _kilit:
        _buda(simdi)
        anahtar = _anahtar(email, ip)
        _hatalar[anahtar] = (_taze(_hatalar.get(anahtar, []), simdi) + [simdi])[-EN_FAZLA_HATA:]
        _ip_hatalar[ip] = (_taze(_ip_hatalar.get(ip, []), simdi) + [simdi])[-IP_EN_FAZLA_HATA:]


def sifirla(email: str, ip: str) -> None:
    """Başarılı girişte yalnız o (e-posta, IP) sayacını sıfırlar."""
    with _kilit:
        _hatalar.pop(_anahtar(email, ip), None)

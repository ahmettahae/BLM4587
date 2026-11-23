"""Türkçe metin yardımcıları: veritabanı sıralaması ve Python'un lower()'ı İ/ı harflerini bilmez."""

_TR_ALFABE = "abcçdefgğhıijklmnoöprsştuüvyz"
_TR_SIRA = {harf: i for i, harf in enumerate(_TR_ALFABE)}


def tr_kucuk(metin: str) -> str:
    """Türkçe kurala göre küçük harfe çevirir: İ -> i, I -> ı."""
    return metin.replace("İ", "i").replace("I", "ı").lower()


def tr_esle(metin: str) -> str:
    """Karşılaştırma anahtarı: Türkçe küçük harf, sonra ı ve i aynı sayılır.
    Böylece "istanbul" "İSTANBUL"u, "isaac" de yabancı adlardaki büyük I'lı "Isaac"ı bulur."""
    return tr_kucuk(metin).replace("ı", "i")


def tr_sirala(ad: str) -> list[int]:
    """Türkçe alfabe sırası için anahtar (Ç, Ğ, İ, Ö, Ş, Ü kendi yerinde)."""
    return [_TR_SIRA.get(h, 100 + ord(h)) for h in tr_kucuk(ad)]

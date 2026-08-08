"""Curated starter vocabulary decks (roughly HSK1/2), grouped by topic."""
from __future__ import annotations

from .models import Deck, DeckWord

_DECKS: dict[str, Deck] = {
    "greetings": Deck(
        id="greetings",
        name="Приветствия",
        words=[
            DeckWord(word="你好", pinyin="nǐ hǎo", translation="привет"),
            DeckWord(word="早上好", pinyin="zǎoshang hǎo", translation="доброе утро"),
            DeckWord(word="晚上好", pinyin="wǎnshang hǎo", translation="добрый вечер"),
            DeckWord(word="再见", pinyin="zàijiàn", translation="до свидания"),
            DeckWord(word="谢谢", pinyin="xièxie", translation="спасибо"),
            DeckWord(word="不客气", pinyin="bú kèqi", translation="пожалуйста (в ответ)"),
            DeckWord(word="对不起", pinyin="duìbuqǐ", translation="извините"),
            DeckWord(word="没关系", pinyin="méi guānxi", translation="ничего страшного"),
        ],
    ),
    "food": Deck(
        id="food",
        name="Еда",
        words=[
            DeckWord(word="米饭", pinyin="mǐfàn", translation="рис"),
            DeckWord(word="面条", pinyin="miàntiáo", translation="лапша"),
            DeckWord(word="水", pinyin="shuǐ", translation="вода"),
            DeckWord(word="茶", pinyin="chá", translation="чай"),
            DeckWord(word="咖啡", pinyin="kāfēi", translation="кофе"),
            DeckWord(word="鸡蛋", pinyin="jīdàn", translation="яйцо"),
            DeckWord(word="牛肉", pinyin="niúròu", translation="говядина"),
            DeckWord(word="水果", pinyin="shuǐguǒ", translation="фрукты"),
            DeckWord(word="好吃", pinyin="hǎochī", translation="вкусный"),
            DeckWord(word="饿", pinyin="è", translation="голодный"),
        ],
    ),
    "family": Deck(
        id="family",
        name="Семья",
        words=[
            DeckWord(word="爸爸", pinyin="bàba", translation="папа"),
            DeckWord(word="妈妈", pinyin="māma", translation="мама"),
            DeckWord(word="哥哥", pinyin="gēge", translation="старший брат"),
            DeckWord(word="姐姐", pinyin="jiějie", translation="старшая сестра"),
            DeckWord(word="弟弟", pinyin="dìdi", translation="младший брат"),
            DeckWord(word="妹妹", pinyin="mèimei", translation="младшая сестра"),
            DeckWord(word="孩子", pinyin="háizi", translation="ребёнок"),
            DeckWord(word="家人", pinyin="jiārén", translation="члены семьи"),
        ],
    ),
    "numbers": Deck(
        id="numbers",
        name="Числа",
        words=[
            DeckWord(word="一", pinyin="yī", translation="один"),
            DeckWord(word="二", pinyin="èr", translation="два"),
            DeckWord(word="三", pinyin="sān", translation="три"),
            DeckWord(word="四", pinyin="sì", translation="четыре"),
            DeckWord(word="五", pinyin="wǔ", translation="пять"),
            DeckWord(word="六", pinyin="liù", translation="шесть"),
            DeckWord(word="七", pinyin="qī", translation="семь"),
            DeckWord(word="八", pinyin="bā", translation="восемь"),
            DeckWord(word="九", pinyin="jiǔ", translation="девять"),
            DeckWord(word="十", pinyin="shí", translation="десять"),
        ],
    ),
    "time": Deck(
        id="time",
        name="Время",
        words=[
            DeckWord(word="今天", pinyin="jīntiān", translation="сегодня"),
            DeckWord(word="明天", pinyin="míngtiān", translation="завтра"),
            DeckWord(word="昨天", pinyin="zuótiān", translation="вчера"),
            DeckWord(word="现在", pinyin="xiànzài", translation="сейчас"),
            DeckWord(word="小时", pinyin="xiǎoshí", translation="час"),
            DeckWord(word="分钟", pinyin="fēnzhōng", translation="минута"),
            DeckWord(word="星期", pinyin="xīngqī", translation="неделя"),
            DeckWord(word="月", pinyin="yuè", translation="месяц"),
        ],
    ),
}


def list_decks() -> list[Deck]:
    return list(_DECKS.values())


def get_deck(deck_id: str) -> Deck | None:
    return _DECKS.get(deck_id)

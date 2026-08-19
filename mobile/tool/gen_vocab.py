# Regenerates assets/seed/words.json and assets/seed/decks.json.
#
# Kept as a script rather than hand-edited JSON because the two files have to
# agree (deck ids, per-deck word_count) and every word needs the same field
# set — both are easy to get subtly wrong across 300 entries by hand.
#
# Word ids are stable, human-readable slugs: SRS progress in the on-device
# database is keyed by word id, so renaming one silently orphans a learner's
# history for that word.
#
# Run: python tool/gen_vocab.py
import json
import os
import sys

# (hanzi, pinyin, translation_ru, id, example_sentence, example_translation)
# example_* may be None.
HSK1 = {
    "greetings": ("Приветствия", [
        ("你好", "nǐ hǎo", "привет", "nihao", "你好！", "Привет!"),
        ("谢谢", "xiè xie", "спасибо", "xiexie", "谢谢你。", "Спасибо тебе."),
        ("不客气", "bù kè qi", "не за что", "bukeqi", None, None),
        ("再见", "zài jiàn", "до свидания", "zaijian", "明天再见。", "До завтра."),
        ("请", "qǐng", "пожалуйста", "qing", "请坐。", "Садитесь, пожалуйста."),
        ("对不起", "duì bu qǐ", "извините", "duibuqi", None, None),
        ("没关系", "méi guān xi", "ничего страшного", "meiguanxi", None, None),
        ("喂", "wèi", "алло", "wei", None, None),
        ("先生", "xiān sheng", "господин", "xiansheng", None, None),
        ("小姐", "xiǎo jiě", "госпожа", "xiaojie", None, None),
    ]),
    "numbers": ("Числа", [
        ("一", "yī", "один", "yi", None, None),
        ("二", "èr", "два", "er", None, None),
        ("三", "sān", "три", "san", None, None),
        ("四", "sì", "четыре", "si", None, None),
        ("五", "wǔ", "пять", "wu", None, None),
        ("六", "liù", "шесть", "liu", None, None),
        ("七", "qī", "семь", "qi", None, None),
        ("八", "bā", "восемь", "ba", None, None),
        ("九", "jiǔ", "девять", "jiu", None, None),
        ("十", "shí", "десять", "shi", None, None),
        ("零", "líng", "ноль", "ling", None, None),
        ("百", "bǎi", "сто", "bai", None, None),
        ("几", "jǐ", "сколько (немного)", "ji", "几个人？", "Сколько человек?"),
        ("多少", "duō shao", "сколько", "duoshao", "多少钱？", "Сколько стоит?"),
    ]),
    "people": ("Люди и местоимения", [
        ("我", "wǒ", "я", "wo", "我是学生。", "Я студент."),
        ("你", "nǐ", "ты", "ni", None, None),
        ("他", "tā", "он", "ta_m", None, None),
        ("她", "tā", "она", "ta_f", None, None),
        ("我们", "wǒ men", "мы", "women", None, None),
        ("人", "rén", "человек", "ren", None, None),
        ("学生", "xué sheng", "студент", "xuesheng", None, None),
        ("老师", "lǎo shī", "учитель", "laoshi", "他是老师。", "Он учитель."),
        ("同学", "tóng xué", "одноклассник", "tongxue", None, None),
        ("医生", "yī shēng", "врач", "yisheng", None, None),
        ("名字", "míng zi", "имя", "mingzi", "你叫什么名字？", "Как тебя зовут?"),
        ("叫", "jiào", "звать(ся)", "jiao", None, None),
        ("认识", "rèn shi", "быть знакомым", "renshi", None, None),
        ("岁", "suì", "лет (возраст)", "sui", None, None),
    ]),
    "family": ("Семья", [
        ("爸爸", "bà ba", "папа", "baba", None, None),
        ("妈妈", "mā ma", "мама", "mama", None, None),
        ("哥哥", "gē ge", "старший брат", "gege", None, None),
        ("姐姐", "jiě jie", "старшая сестра", "jiejie", None, None),
        ("弟弟", "dì di", "младший брат", "didi", None, None),
        ("妹妹", "mèi mei", "младшая сестра", "meimei", None, None),
        ("儿子", "ér zi", "сын", "erzi", None, None),
        ("女儿", "nǚ ér", "дочь", "nver", None, None),
        ("家", "jiā", "дом / семья", "jia", "我家有四个人。", "В моей семье четыре человека."),
        ("朋友", "péng you", "друг", "pengyou", None, None),
    ]),
    "food": ("Еда и напитки", [
        ("米饭", "mǐ fàn", "рис", "mifan", None, None),
        ("菜", "cài", "блюдо / овощи", "cai", None, None),
        ("水", "shuǐ", "вода", "shui", "我要喝水。", "Я хочу пить воду."),
        ("茶", "chá", "чай", "cha", None, None),
        ("苹果", "píng guǒ", "яблоко", "pingguo", None, None),
        ("水果", "shuǐ guǒ", "фрукты", "shuiguo", None, None),
        ("杯子", "bēi zi", "стакан / чашка", "beizi", None, None),
        ("吃", "chī", "есть (кушать)", "chi", "我吃米饭。", "Я ем рис."),
        ("喝", "hē", "пить", "he", None, None),
        ("饭馆", "fàn guǎn", "ресторан", "fanguan", None, None),
    ]),
    "time": ("Время", [
        ("今天", "jīn tiān", "сегодня", "jintian", None, None),
        ("明天", "míng tiān", "завтра", "mingtian", None, None),
        ("昨天", "zuó tiān", "вчера", "zuotian", None, None),
        ("现在", "xiàn zài", "сейчас", "xianzai", None, None),
        ("上午", "shàng wǔ", "утро (до полудня)", "shangwu", None, None),
        ("中午", "zhōng wǔ", "полдень", "zhongwu", None, None),
        ("下午", "xià wǔ", "день (после полудня)", "xiawu", None, None),
        ("星期", "xīng qī", "неделя", "xingqi", None, None),
        ("年", "nián", "год", "nian", None, None),
        ("月", "yuè", "месяц", "yue", None, None),
        ("号", "hào", "число (даты)", "hao_date", None, None),
        ("点", "diǎn", "час (время)", "dian", "现在几点？", "Который сейчас час?"),
        ("分钟", "fēn zhōng", "минута", "fenzhong", None, None),
        ("时候", "shí hou", "время / момент", "shihou", None, None),
    ]),
    "questions": ("Вопросы", [
        ("什么", "shén me", "что", "shenme", "这是什么？", "Что это?"),
        ("谁", "shéi", "кто", "shei", None, None),
        ("哪", "nǎ", "какой", "na_which", None, None),
        ("哪儿", "nǎ r", "где", "nar", "你在哪儿？", "Ты где?"),
        ("怎么", "zěn me", "как", "zenme", None, None),
        ("怎么样", "zěn me yàng", "как насчёт", "zenmeyang", None, None),
        ("吗", "ma", "вопросительная частица", "ma_q", "你好吗？", "Как дела?"),
        ("呢", "ne", "а (частица)", "ne", None, None),
    ]),
    "verbs1": ("Глаголы: основа", [
        ("是", "shì", "быть / являться", "shi_verb", None, None),
        ("有", "yǒu", "иметь", "you", None, None),
        ("没有", "méi yǒu", "не иметь", "meiyou", None, None),
        ("看", "kàn", "смотреть", "kan", None, None),
        ("看见", "kàn jiàn", "увидеть", "kanjian", None, None),
        ("听", "tīng", "слушать", "ting", None, None),
        ("说", "shuō", "говорить", "shuo", None, None),
        ("读", "dú", "читать", "du", None, None),
        ("写", "xiě", "писать", "xie", "我写字。", "Я пишу иероглифы."),
        ("想", "xiǎng", "хотеть / думать", "xiang", None, None),
        ("喜欢", "xǐ huan", "нравиться", "xihuan", "我喜欢茶。", "Мне нравится чай."),
        ("爱", "ài", "любить", "ai", None, None),
        ("会", "huì", "уметь", "hui", None, None),
        ("能", "néng", "мочь", "neng", None, None),
        ("做", "zuò", "делать", "zuo_do", None, None),
        ("买", "mǎi", "покупать", "mai", None, None),
        ("开", "kāi", "открывать", "kai", None, None),
        ("住", "zhù", "жить (проживать)", "zhu", None, None),
        ("睡觉", "shuì jiào", "спать", "shuijiao", None, None),
        ("打电话", "dǎ diàn huà", "звонить", "dadianhua", None, None),
        ("工作", "gōng zuò", "работать / работа", "gongzuo", None, None),
        ("学习", "xué xí", "учиться", "xuexi", None, None),
    ]),
    "adjectives1": ("Признаки", [
        ("好", "hǎo", "хороший", "hao", None, None),
        ("大", "dà", "большой", "da", None, None),
        ("小", "xiǎo", "маленький", "xiao", None, None),
        ("多", "duō", "много", "duo", None, None),
        ("少", "shǎo", "мало", "shao", None, None),
        ("冷", "lěng", "холодный", "leng", None, None),
        ("热", "rè", "жаркий", "re", None, None),
        ("高兴", "gāo xìng", "радостный", "gaoxing", None, None),
        ("漂亮", "piào liang", "красивый", "piaoliang", None, None),
        ("很", "hěn", "очень", "hen", "我很好。", "У меня всё хорошо."),
        ("太", "tài", "слишком", "tai", None, None),
        ("不", "bù", "не", "bu", None, None),
        ("都", "dōu", "все / всё", "dou", None, None),
    ]),
    "places1": ("Места", [
        ("学校", "xué xiào", "школа", "xuexiao", None, None),
        ("商店", "shāng diàn", "магазин", "shangdian", None, None),
        ("医院", "yī yuàn", "больница", "yiyuan", None, None),
        ("中国", "zhōng guó", "Китай", "zhongguo", None, None),
        ("北京", "běi jīng", "Пекин", "beijing", None, None),
        ("里", "lǐ", "внутри", "li", None, None),
        ("上", "shàng", "верх / на", "shang", None, None),
        ("下", "xià", "низ / под", "xia", None, None),
        ("前面", "qián miàn", "впереди", "qianmian", None, None),
        ("后面", "hòu miàn", "позади", "houmian", None, None),
        ("在", "zài", "находиться в", "zai", "我在家。", "Я дома."),
    ]),
    "objects1": ("Предметы", [
        ("书", "shū", "книга", "shu", None, None),
        ("字", "zì", "иероглиф", "zi", None, None),
        ("桌子", "zhuō zi", "стол", "zhuozi", None, None),
        ("椅子", "yǐ zi", "стул", "yizi", None, None),
        ("电脑", "diàn nǎo", "компьютер", "diannao", None, None),
        ("电视", "diàn shì", "телевизор", "dianshi", None, None),
        ("电影", "diàn yǐng", "фильм", "dianying", None, None),
        ("衣服", "yī fu", "одежда", "yifu", None, None),
        ("东西", "dōng xi", "вещь", "dongxi", None, None),
        ("钱", "qián", "деньги", "qian", None, None),
        ("猫", "māo", "кошка", "mao", None, None),
        ("狗", "gǒu", "собака", "gou", None, None),
    ]),
    "grammar1": ("Служебные слова", [
        ("的", "de", "притяжательная частица", "de", "我的书", "моя книга"),
        ("了", "le", "частица завершённости", "le", None, None),
        ("和", "hé", "и", "he_and", None, None),
        ("这", "zhè", "это", "zhe", None, None),
        ("那", "nà", "то", "na_that", None, None),
        ("个", "gè", "счётное слово (общее)", "ge", None, None),
        ("本", "běn", "счётное слово (книги)", "ben", None, None),
        ("块", "kuài", "юань (счётное)", "kuai", None, None),
        ("些", "xiē", "несколько", "xie_some", None, None),
        ("一点儿", "yì diǎn r", "немного", "yidianr", None, None),
        ("汉语", "hàn yǔ", "китайский язык", "hanyu", "我学习汉语。", "Я учу китайский."),
        ("天气", "tiān qì", "погода", "tianqi", None, None),
        ("下雨", "xià yǔ", "идёт дождь", "xiayu", None, None),
        ("回", "huí", "возвращаться", "hui_return", None, None),
        ("来", "lái", "приходить", "lai", None, None),
        ("去", "qù", "идти / ехать (туда)", "qu", None, None),
        ("坐", "zuò", "сидеть / ехать на", "zuo", None, None),
        ("出租车", "chū zū chē", "такси", "chuzuche", None, None),
        ("飞机", "fēi jī", "самолёт", "feiji", None, None),
    ]),
}

HSK2 = {
    "colors": ("Цвета", [
        ("红色", "hóng sè", "красный", "hongse", None, None),
        ("黄色", "huáng sè", "жёлтый", "huangse", None, None),
        ("蓝色", "lán sè", "синий", "lanse", None, None),
        ("绿色", "lǜ sè", "зелёный", "lvse", None, None),
        ("黑色", "hēi sè", "чёрный", "heise", None, None),
        ("白色", "bái sè", "белый", "baise", None, None),
        ("颜色", "yán sè", "цвет", "yanse", None, None),
    ]),
    "movement": ("Движение", [
        ("走", "zǒu", "идти пешком", "zou", None, None),
        ("跑步", "pǎo bù", "бегать", "paobu", None, None),
        ("进", "jìn", "входить", "jin", None, None),
        ("出", "chū", "выходить", "chu", None, None),
        ("回家", "huí jiā", "возвращаться домой", "huijia", None, None),
        ("上班", "shàng bān", "идти на работу", "shangban", None, None),
        ("旅游", "lǚ yóu", "путешествовать", "lvyou", None, None),
        ("送", "sòng", "провожать / дарить", "song", None, None),
        ("找", "zhǎo", "искать", "zhao", None, None),
        ("到", "dào", "прибывать", "dao", None, None),
    ]),
    "food2": ("Еда: продолжение", [
        ("面条", "miàn tiáo", "лапша", "miantiao", None, None),
        ("咖啡", "kā fēi", "кофе", "kafei", None, None),
        ("鸡蛋", "jī dàn", "яйцо", "jidan", None, None),
        ("牛奶", "niú nǎi", "молоко", "niunai", None, None),
        ("羊肉", "yáng ròu", "баранина", "yangrou", None, None),
        ("鱼", "yú", "рыба", "yu", None, None),
        ("西瓜", "xī guā", "арбуз", "xigua", None, None),
        ("好吃", "hǎo chī", "вкусный", "haochi", None, None),
        ("服务员", "fú wù yuán", "официант", "fuwuyuan", None, None),
        ("饿", "è", "голодный", "e", None, None),
    ]),
    "study2": ("Учёба", [
        ("考试", "kǎo shì", "экзамен", "kaoshi", None, None),
        ("问题", "wèn tí", "вопрос / проблема", "wenti", None, None),
        ("问", "wèn", "спрашивать", "wen", None, None),
        ("回答", "huí dá", "отвечать", "huida", None, None),
        ("懂", "dǒng", "понимать", "dong", None, None),
        ("知道", "zhī dào", "знать", "zhidao", None, None),
        ("觉得", "jué de", "считать / полагать", "juede", None, None),
        ("意思", "yì si", "смысл", "yisi", None, None),
        ("课", "kè", "урок", "ke", None, None),
        ("教室", "jiào shì", "аудитория", "jiaoshi", None, None),
        ("铅笔", "qiān bǐ", "карандаш", "qianbi", None, None),
        ("报纸", "bào zhǐ", "газета", "baozhi", None, None),
    ]),
    "shopping2": ("Покупки", [
        ("卖", "mài", "продавать", "mai_sell", None, None),
        ("贵", "guì", "дорогой", "gui", None, None),
        ("便宜", "pián yi", "дешёвый", "pianyi", None, None),
        ("元", "yuán", "юань", "yuan", None, None),
        ("公斤", "gōng jīn", "килограмм", "gongjin", None, None),
        ("件", "jiàn", "счётное (одежда)", "jian", None, None),
        ("穿", "chuān", "надевать", "chuan", None, None),
        ("帮助", "bāng zhù", "помогать", "bangzhu", None, None),
        ("给", "gěi", "давать", "gei", None, None),
        ("门", "mén", "дверь", "men", None, None),
    ]),
    "body2": ("Тело и здоровье", [
        ("眼睛", "yǎn jing", "глаза", "yanjing", None, None),
        ("手", "shǒu", "рука", "shou", None, None),
        ("身体", "shēn tǐ", "тело / здоровье", "shenti", None, None),
        ("生病", "shēng bìng", "заболеть", "shengbing", None, None),
        ("药", "yào", "лекарство", "yao", None, None),
        ("累", "lèi", "усталый", "lei", None, None),
        ("休息", "xiū xi", "отдыхать", "xiuxi", None, None),
        ("运动", "yùn dòng", "спорт / заниматься спортом", "yundong", None, None),
        ("洗", "xǐ", "мыть", "xi", None, None),
        ("起床", "qǐ chuáng", "вставать с постели", "qichuang", None, None),
    ]),
    "transport2": ("Транспорт и город", [
        ("公共汽车", "gōng gòng qì chē", "автобус", "gonggongqiche", None, None),
        ("火车", "huǒ chē", "поезд", "huoche", None, None),
        ("自行车", "zì xíng chē", "велосипед", "zixingche", None, None),
        ("车站", "chē zhàn", "остановка / вокзал", "chezhan", None, None),
        ("机场", "jī chǎng", "аэропорт", "jichang", None, None),
        ("宾馆", "bīn guǎn", "гостиница", "binguan", None, None),
        ("房间", "fáng jiān", "комната", "fangjian", None, None),
        ("路", "lù", "дорога", "lu", None, None),
        ("公司", "gōng sī", "компания", "gongsi", None, None),
        ("远", "yuǎn", "далёкий", "yuan_far", None, None),
        ("近", "jìn", "близкий", "jin_near", None, None),
    ]),
    "adverbs2": ("Наречия и связки", [
        ("因为", "yīn wèi", "потому что", "yinwei", None, None),
        ("所以", "suǒ yǐ", "поэтому", "suoyi", None, None),
        ("但是", "dàn shì", "но", "danshi", None, None),
        ("还是", "hái shi", "или (в вопросе)", "haishi", None, None),
        ("也", "yě", "тоже", "ye", None, None),
        ("再", "zài", "ещё раз", "zai_again", None, None),
        ("就", "jiù", "именно / сразу", "jiu_then", None, None),
        ("已经", "yǐ jīng", "уже", "yijing", None, None),
        ("正在", "zhèng zài", "прямо сейчас", "zhengzai", None, None),
        ("最", "zuì", "самый", "zui", None, None),
        ("非常", "fēi cháng", "чрезвычайно", "feichang", None, None),
        ("比", "bǐ", "по сравнению с", "bi", None, None),
        ("可能", "kě néng", "возможно", "keneng", None, None),
        ("应该", "yīng gāi", "следует", "yinggai", None, None),
        ("一起", "yì qǐ", "вместе", "yiqi", None, None),
        ("每", "měi", "каждый", "mei", None, None),
    ]),
    "daily2": ("Повседневное", [
        ("时间", "shí jiān", "время", "shijian", None, None),
        ("小时", "xiǎo shí", "час", "xiaoshi", None, None),
        ("生日", "shēng rì", "день рождения", "shengri", None, None),
        ("希望", "xī wàng", "надеяться", "xiwang", None, None),
        ("准备", "zhǔn bèi", "готовиться", "zhunbei", None, None),
        ("开始", "kāi shǐ", "начинать", "kaishi", None, None),
        ("完", "wán", "закончить", "wan", None, None),
        ("笑", "xiào", "смеяться", "xiao_laugh", None, None),
        ("唱歌", "chàng gē", "петь", "changge", None, None),
        ("跳舞", "tiào wǔ", "танцевать", "tiaowu", None, None),
        ("玩", "wán", "играть", "wan_play", None, None),
        ("介绍", "jiè shào", "представлять", "jieshao", None, None),
        ("等", "děng", "ждать", "deng", None, None),
        ("让", "ràng", "позволять", "rang", None, None),
        ("新", "xīn", "новый", "xin", None, None),
        ("快", "kuài", "быстрый", "kuai_fast", None, None),
        ("慢", "màn", "медленный", "man", None, None),
        ("忙", "máng", "занятой", "mang", None, None),
        ("晴", "qíng", "ясный (о погоде)", "qing_clear", None, None),
        ("阴", "yīn", "пасмурный", "yin", None, None),
    ]),
}


def build():
    decks = []
    words = []
    seen_ids = set()
    seen_hanzi = set()

    for level, groups in ((1, HSK1), (2, HSK2)):
        for deck_id, (title, entries) in groups.items():
            clean = entries
            for hanzi, pinyin, ru, wid, ex, ex_ru in clean:
                if wid in seen_ids:
                    sys.exit(f"duplicate word id: {wid}")
                if hanzi in seen_hanzi:
                    sys.exit(f"duplicate hanzi: {hanzi} ({wid})")
                seen_ids.add(wid)
                seen_hanzi.add(hanzi)
                words.append({
                    "id": wid,
                    "hanzi": hanzi,
                    "pinyin": pinyin,
                    "translation_ru": ru,
                    "example_sentence": ex,
                    "example_translation": ex_ru,
                    "hsk_level": level,
                    "topic": deck_id,
                    "deck_id": deck_id,
                })
            decks.append({
                "id": deck_id,
                "title": title,
                "topic": deck_id,
                "hsk_level": level,
                "word_count": len(clean),
            })

    root = os.path.join(os.path.dirname(__file__), "..", "assets", "seed")
    with open(os.path.join(root, "words.json"), "w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
        f.write("\n")
    with open(os.path.join(root, "decks.json"), "w", encoding="utf-8") as f:
        json.dump(decks, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"decks: {len(decks)}  words: {len(words)}")
    for level in (1, 2):
        print(f"  HSK{level}: {sum(1 for w in words if w['hsk_level'] == level)}")


if __name__ == "__main__":
    build()

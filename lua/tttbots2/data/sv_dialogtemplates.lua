local Dialog = TTTBots.Locale.Dialog ---@type TTTBots.DialogModule

-- Greet each other v1
Dialog.NewTemplate(
    "Greetings1",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
    },
    false
)

-- Greet each other v2 - what's up
Dialog.NewTemplate(
    "Greetings2",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
        Dialog.NewLine("WhatsUp", 1),
        Dialog.NewLine("WhatsUpResponse", 2),
    },
    false
)


-- Greet each other v3 - how are you
Dialog.NewTemplate(
    "Greetings3",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
        Dialog.NewLine("HowAreYou", 1),
        Dialog.NewLine("HowAreYouResponse", 2),
    },
    false
)

-- Greet each other v4 - unreciprocated
Dialog.NewTemplate(
    "Greetings4",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
    },
    false
)

-- Say self is bored v1 - 1 positive response
Dialog.NewTemplate(
    "Bored1",
    2,
    {
        Dialog.NewLine("AnyoneBored", 1),
        Dialog.NewLine("PositiveResponse", 2),
    },
    false
)

-- Say self is bored v2 - 2 negative response
Dialog.NewTemplate(
    "Bored2",
    3,
    {
        Dialog.NewLine("AnyoneBored", 1),
        Dialog.NewLine("NegativeResponse", 2),
        Dialog.NewLine("NegativeResponse", 3),
    },
    false
)

-- Say self is bored v3 - rude response
Dialog.NewTemplate(
    "Bored3",
    2,
    {
        Dialog.NewLine("AnyoneBored", 1),
        Dialog.NewLine("RudeResponse", 2),
    },
    false
)

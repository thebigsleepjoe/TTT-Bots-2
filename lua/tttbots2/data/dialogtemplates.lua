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
    "Greetings1",
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
    "Greetings1",
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
    "Greetings1",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
    },
    false
)

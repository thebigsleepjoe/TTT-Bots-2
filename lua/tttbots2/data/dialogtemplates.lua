local Dialog = TTTBots.Locale.Dialog ---@type TTTBots.DialogModule

-- Greet each other 1
Dialog.NewTemplate(
    "Greetings1",
    2,
    {
        Dialog.NewLine("GreetNext", 1),
        Dialog.NewLine("GreetLast", 2),
    },
    false
)

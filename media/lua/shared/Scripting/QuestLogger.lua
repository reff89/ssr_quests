-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
QuestLogger = {}
QuestLogger.verbose = false;
QuestLogger.mute = false;
QuestLogger.error = false;

function QuestLogger.print(text)
    if QuestLogger.verbose then
        if QuestLogger.mute then return end
        print(text);
    end
end

function QuestLogger.report(message)
    addLineInChat(message, 0);
end
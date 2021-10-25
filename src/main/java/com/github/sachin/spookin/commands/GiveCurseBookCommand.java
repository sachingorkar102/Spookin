package com.github.sachin.spookin.commands;

import java.util.Arrays;
import java.util.stream.Collector;
import java.util.stream.Collectors;

import com.github.sachin.spookin.modules.curses.BaseCurse;
import com.github.sachin.spookin.modules.curses.CurseModule;

import org.bukkit.ChatColor;
import org.bukkit.entity.Player;

public class GiveCurseBookCommand extends SubCommand{

    private final CurseModule module;

    public GiveCurseBookCommand() {
        super("gives player a curse book", "givebook", "spookin.command.givebook", "/spookin givebook [book-name]");
        this.module = (CurseModule)plugin.getModuleManager().getModuleFromName("curses");
        addCompletion(2,module.registeredCurses.stream().map(c -> c.id).collect(Collectors.toList()));
    }

    @Override
    public void execute(Player player, String[] args) {
        if(args.length != 2) return;
        String curseName = args[1];
        for(BaseCurse c : module.registeredCurses){
            if(curseName.equals(c.id)){
                player.getInventory().addItem(c.bindBook(player));
                player.sendMessage(ChatColor.translateAlternateColorCodes('&', "Gave player "+c.name+"&r book"));
            }
        }
    }


    
}

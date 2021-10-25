package com.github.sachin.spookin.commands;

import org.bukkit.entity.Player;

public class SummonCommand extends SubCommand{

    public SummonCommand() {
        super("Summons a spooky mob", "summon", "spookin.command.summon", "/spookin summon [mob-name]");
    }
 
    
    @Override
    public void execute(Player player, String[] args) {
        plugin.getNmsHelper().summonSkeleHead(player.getLocation());   
    }
}

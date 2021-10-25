package com.github.sachin.spookin.commands;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

import com.github.sachin.spookin.Spookin;

import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

public abstract class SubCommand {
    
    protected final Spookin plugin = Spookin.getPlugin();
    public final String description;
    public final String name;
    public final String permission;
    public final String syntax;
    private final Map<Integer,List<String>> completions = new HashMap<>();
    protected final Logger LOGGER = Spookin.getPlugin().getLogger();



    public SubCommand(String description, String name,String permission,String syntax) {
        this.description = description;
        this.name = name;
        this.permission = permission;
        this.syntax = syntax;
    }


    public void addCompletion(int i,List<String> completion){
        completions.put(i,completion);
    }

    public Map<Integer, List<String>> getCompletions() {
        return completions;
    }

    public void execute(Player player,String[] args){}

    public void execute(CommandSender sender,String[] args){}

}

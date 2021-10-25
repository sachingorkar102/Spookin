package com.github.sachin.spookin.commands;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import com.github.sachin.spookin.Spookin;

import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;

public class CommandManager implements CommandExecutor,TabCompleter{


    private Spookin plugin;
    private List<SubCommand> subCommands = new ArrayList<>();
    private List<String> commandList = new ArrayList<>();

    public CommandManager(Spookin plugin){
        this.plugin = plugin;
        registerSubCommands();
    }


    public void registerSubCommands(){
        subCommands.add(new GiveCommand());
        subCommands.add(new ReloadCommand());
        subCommands.add(new GiveCurseBookCommand());
        subCommands.add(new SearchCommand());
        // subCommands.add(new SummonCommand());
        for(SubCommand sub : subCommands){
            commandList.add(sub.name);
        }
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        
        for(SubCommand sub : subCommands){
            if(args[0].equalsIgnoreCase(sub.name) && sender.hasPermission(sub.permission)){
                
                if(sender instanceof Player){
                    sub.execute((Player)sender, args);
                }
                else{
                    sub.execute(sender, args);
                }
            }    
        }
        return false;
    }


    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        if(args.length==0) return null;
        if(args.length == 1) return getBetterArgs(commandList, args[0]);
        for(SubCommand sub : subCommands){
            if(sub.name.equals(args[0]) && sub.getCompletions().keySet().contains(args.length)){
                if(sub.getCompletions().get(args.length) == null){
                    return null;
                }
                return getBetterArgs(sub.getCompletions().get(args.length), args[args.length-1]);
            }
        }
        return null;
    }

    public List<String> getBetterArgs(List<String> normalArgs,String currentArg){
        List<String> betterArgs = new ArrayList<>();
        normalArgs.forEach(s -> {
            if(s.startsWith(currentArg)){
                betterArgs.add(s);
            }
        });
        if(betterArgs.isEmpty()){
            return normalArgs;
        }
        else{
            return betterArgs;
        }
    }
    
}

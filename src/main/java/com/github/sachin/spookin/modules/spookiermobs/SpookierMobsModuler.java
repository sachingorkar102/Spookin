package com.github.sachin.spookin.modules.spookiermobs;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

import com.github.sachin.spookin.BaseModule;
import com.github.sachin.spookin.manager.Module;

import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.Sound;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.entity.Creeper;
import org.bukkit.entity.Drowned;
import org.bukkit.entity.Enderman;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.entity.Husk;
import org.bukkit.entity.Player;
import org.bukkit.entity.TNTPrimed;
import org.bukkit.entity.Witch;
import org.bukkit.entity.Zombie;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.entity.EntityExplodeEvent;
import org.bukkit.event.entity.EntitySpawnEvent;
import org.bukkit.event.entity.EntityTargetLivingEntityEvent;
import org.bukkit.inventory.ItemStack;
import org.bukkit.scheduler.BukkitRunnable;

@Module(name = "spookier-mobs")
public class SpookierMobsModuler extends BaseModule implements Listener{

    @EventHandler
    public void onEntityTarget(EntityTargetLivingEntityEvent e){
        
        if(e.getEntity().getType()==EntityType.ENDERMAN && e.getTarget() != null &&  e.getTarget().getType()==EntityType.PLAYER){
            Enderman enderman = (Enderman) e.getEntity();
            Player player = (Player) e.getTarget();
            if(enderman.getCarriedBlock() != null && enderman.getCarriedBlock().getMaterial()==Material.TNT){
                List<Block> list = getNearbyBlocks(player.getLocation(), 4);
                if(!list.isEmpty()){
                    Block target = list.get(plugin.RANDOM.nextInt(list.size()));
                    enderman.teleport(target.getLocation().add(0.5, 0.5, 0.5));
                    enderman.setCarriedBlock(null);
                    TNTPrimed tnt = player.getWorld().spawn(target.getLocation().add(0.5, 1, 0.5), TNTPrimed.class);
                    player.getWorld().playSound(target.getLocation(), Sound.ENTITY_TNT_PRIMED, 2F,  plugin.RANDOM.nextFloat() * 0.4F + 0.8F);
                    tnt.setFuseTicks(70);
                    enderman.teleportRandomly();
                }
            }
        }
    }

    public static List<Block> getNearbyBlocks(Location location, int radius) {
        List<Block> blocks = new ArrayList<Block>();
        for(int x = location.getBlockX() - radius; x <= location.getBlockX() + radius; x++) {
            for(int y = location.getBlockY() - radius; y <= location.getBlockY() + radius; y++) {
                for(int z = location.getBlockZ() - radius; z <= location.getBlockZ() + radius; z++) {
                   Block block = location.getWorld().getBlockAt(x, y, z);
                   Block b1 = block.getRelative(BlockFace.UP);
                   Block b2 = b1.getRelative(BlockFace.UP);
                   Block b3 = b2.getRelative(BlockFace.UP);
                   if(block.isSolid() && b1.getType()==Material.AIR && b2.getType()==Material.AIR && b3.getType()==Material.AIR){
                       blocks.add(location.getWorld().getBlockAt(x, y, z));
                   } 
                }
            }
        }
        return blocks;
    }
    
    @EventHandler
    public void onSpawn(EntitySpawnEvent e){
        Entity en = e.getEntity();
        World world = en.getWorld();
        if(plugin.RANDOM.nextInt(30) < 5){
            new BukkitRunnable() {
                @Override
                public void run() {
                    if(en.isDead()) return;
                    if(en instanceof Zombie && ((Zombie)en).isAdult()){
                        if(en.getType()==EntityType.ZOMBIE){
                            Zombie baby =  world.spawn(en.getLocation(),Zombie.class);
                            baby.setBaby();
                            en.addPassenger(baby);  
                        }
                        else if(en.getType()==EntityType.HUSK){
                            Husk baby = world.spawn(en.getLocation(), Husk.class);
                            baby.setBaby();
                            en.addPassenger(baby);
                        }
                        else if(en.getType()==EntityType.DROWNED){
                            Drowned baby = world.spawn(en.getLocation(), Drowned.class);
                            baby.setBaby();
                            en.addPassenger(baby);
                        }
                    }
                }
            }.runTaskLater(plugin, 2);
            if(en.getType()==EntityType.ENDERMAN){
                Enderman enderman = (Enderman) en;
                enderman.setCarriedBlock(Material.TNT.createBlockData());
            }
        }
    }

    @EventHandler
    public void onCreeperDeath(EntityDeathEvent e){
        if(e.getEntity() instanceof Creeper && plugin.RANDOM.nextInt(10) < 5 && e.getEntity().getLastDamageCause() instanceof EntityDamageByEntityEvent){
            e.getEntity().getWorld().createExplosion(e.getEntity(),4F,false);
        }
        else if(e.getEntity() instanceof Witch){
            if(plugin.RANDOM.nextInt(20) < 5){
                ItemStack item = plugin.getItemFolder().SWIRLY_POP;
                item.setAmount(ThreadLocalRandom.current().nextInt(1, 10));
                e.getDrops().add(item);
            }
            if(plugin.RANDOM.nextInt(20) < 5){
                ItemStack candy = plugin.getItemFolder().CANDY;
                candy.setAmount(ThreadLocalRandom.current().nextInt(1, 10));
                e.getDrops().add(candy);
            }if(plugin.RANDOM.nextInt(20) < 5){
                ItemStack candybar = plugin.getItemFolder().CANDY_BAR;
                candybar.setAmount(ThreadLocalRandom.current().nextInt(1, 10));
                e.getDrops().add(candybar);
            }
        }
    }
}

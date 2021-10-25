package com.github.sachin.spookin.modules.jackolauncher;

import java.util.List;

import com.github.sachin.spookin.Spookin;

import org.apache.logging.log4j.core.layout.SyslogLayout;
import org.bukkit.Particle;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.entity.Creeper;
import org.bukkit.entity.Firework;
import org.bukkit.entity.Player;
import org.bukkit.entity.Snowball;
import org.bukkit.entity.ThrownPotion;
import org.bukkit.inventory.meta.FireworkMeta;
import org.bukkit.scheduler.BukkitRunnable;
import org.bukkit.util.Vector;

public class ProjectileRunnable  extends BukkitRunnable{
    
    public final Snowball projectile;
    public final ProjectileHelper helper;
    private final World world;
    public int tick=0;

    public ProjectileRunnable(Snowball projectile,ProjectileHelper helper){
        this.helper = helper;
        this.projectile = projectile;
        this.world = projectile.getWorld();
    }

    @Override
    public void run() {
        if(projectile.isDead() || tick==60){
            this.cancel();
            world.createExplosion(projectile, helper.yeild,helper.hasFireCharge,!helper.isMuffled);
            if(helper.fireWork != null){
                FireworkMeta meta = (FireworkMeta) helper.fireWork.getItemMeta();
                Firework firework = world.spawn(projectile.getLocation(), Firework.class);
                FireworkMeta fireworkMeta = firework.getFireworkMeta();
                fireworkMeta.addEffects(meta.getEffects());
                firework.setFireworkMeta(fireworkMeta);
                new BukkitRunnable() {
                    @Override
                    public void run() {
                        firework.detonate();
                    }
                }.runTaskLater(Spookin.getPlugin(), 1);
            }
            if(helper.applyBoneMeal && helper.isMuffled){
                int radius = 3;
                List<Block> list = JackOLauncherModule.getNearbyBlocks(projectile.getLocation(), radius);
                for(Block b : list){
                    b.applyBoneMeal(BlockFace.UP);
                }
            }
            
            if(helper.isEnderpearl && projectile.getShooter() != null && projectile.getShooter() instanceof Player){
                ((Player)projectile.getShooter()).teleport(projectile.getLocation());
            }
            if(helper.lingeringPotion != null){
                ThrownPotion potion = world.spawn(projectile.getLocation(),ThrownPotion.class);
                potion.setItem(helper.lingeringPotion);
            }
            if(helper.splashPotion != null){
                ThrownPotion potion = world.spawn(projectile.getLocation(),ThrownPotion.class);
                potion.setItem(helper.splashPotion);
            }
            if(!projectile.isDead()){
                projectile.remove();
            }
            return;
        }

        tick++;
        
        if(helper.fireWork != null){
            world.spawnParticle(Particle.FIREWORKS_SPARK,projectile.getLocation(),10,0.1,0.1,0.1,0);
        }
        else{
            projectile.setVelocity(projectile.getVelocity().subtract(new Vector(0, 0.03, 0)));
        }
        world.spawnParticle(Particle.SMOKE_NORMAL, projectile.getLocation(), 30, 0.2, 0.2, 0.2, 0);
    }
}

package net.minecraft.world.entity.ai.goal;

import java.util.EnumSet;
import javax.annotation.Nullable;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.util.DefaultRandomPos;
import net.minecraft.world.phys.Vec3;

public class RandomStrollGoal extends Goal {
  public static final int DEFAULT_INTERVAL = 120;
  
  protected final PathfinderMob mob;
  
  protected double wantedX;
  
  protected double wantedY;
  
  protected double wantedZ;
  
  protected final double speedModifier;
  
  protected int interval;
  
  protected boolean forceTrigger;
  
  private final boolean checkNoActionTime;
  
  public RandomStrollGoal(PathfinderMob param_0, double param_1) {
    this(param_0, param_1, 120);
  }
  
  public RandomStrollGoal(PathfinderMob param_0, double param_1, int param_2) {
    this(param_0, param_1, param_2, true);
  }
  
  public RandomStrollGoal(PathfinderMob param_0, double param_1, int param_2, boolean param_3) {
    this.mob = param_0;
    this.speedModifier = param_1;
    this.interval = param_2;
    this.checkNoActionTime = param_3;
    setFlags(EnumSet.of(Goal.Flag.MOVE));
  }
  
  public boolean canUse() {
    if (this.mob.isVehicle())
      return false; 
    if (!this.forceTrigger) {
      if (this.checkNoActionTime && this.mob.getNoActionTime() >= 100)
        return false; 
      if (this.mob.getRandom().nextInt(this.interval) != 0)
        return false; 
    } 
    Vec3 var_0 = getPosition();
    if (var_0 == null)
      return false; 
    this.wantedX = var_0.x;
    this.wantedY = var_0.y;
    this.wantedZ = var_0.z;
    this.forceTrigger = false;
    return true;
  }
  
  @Nullable
  protected Vec3 getPosition() {
    return DefaultRandomPos.getPos(this.mob, 10, 7);
  }
  
  public boolean canContinueToUse() {
    return (!this.mob.getNavigation().isDone() && !this.mob.isVehicle());
  }
  
  public void start() {
    this.mob.getNavigation().moveTo(this.wantedX, this.wantedY, this.wantedZ, this.speedModifier);
  }
  
  public void stop() {
    this.mob.getNavigation().stop();
    super.stop();
  }
  
  public void trigger() {
    this.forceTrigger = true;
  }
  
  public void setInterval(int param_0) {
    this.interval = param_0;
  }
}

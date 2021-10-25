package net.minecraft.world.entity;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;
import com.google.common.collect.Sets;
import com.google.common.collect.UnmodifiableIterator;
import it.unimi.dsi.fastutil.objects.Object2DoubleArrayMap;
import it.unimi.dsi.fastutil.objects.Object2DoubleMap;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Random;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Predicate;
import java.util.stream.Stream;
import javax.annotation.Nullable;
import net.minecraft.BlockUtil;
import net.minecraft.CrashReport;
import net.minecraft.CrashReportCategory;
import net.minecraft.ReportedException;
import net.minecraft.Util;
import net.minecraft.advancements.CriteriaTriggers;
import net.minecraft.commands.CommandSource;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.arguments.EntityAnchorArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.Vec3i;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.DoubleTag;
import net.minecraft.nbt.FloatTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.StringTag;
import net.minecraft.nbt.Tag;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.HoverEvent;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.network.chat.Style;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientboundAddEntityPacket;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.server.level.TicketType;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.BlockTags;
import net.minecraft.tags.EntityTypeTags;
import net.minecraft.tags.FluidTags;
import net.minecraft.tags.Tag;
import net.minecraft.util.Mth;
import net.minecraft.util.RewindableStream;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.Nameable;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.vehicle.Boat;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.enchantment.EnchantmentHelper;
import net.minecraft.world.item.enchantment.ProtectionEnchantment;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.ChunkPos;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Explosion;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.level.ItemLike;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelHeightAccessor;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.HoneyBlock;
import net.minecraft.world.level.block.Mirror;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.Rotation;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.Property;
import net.minecraft.world.level.border.WorldBorder;
import net.minecraft.world.level.dimension.DimensionType;
import net.minecraft.world.level.entity.EntityAccess;
import net.minecraft.world.level.entity.EntityInLevelCallback;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.level.gameevent.GameEventListenerRegistrar;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.material.Fluid;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.level.portal.PortalInfo;
import net.minecraft.world.level.portal.PortalShape;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec2;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.phys.shapes.BooleanOp;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.minecraft.world.scores.PlayerTeam;
import net.minecraft.world.scores.Team;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public abstract class Entity implements Nameable, EntityAccess, CommandSource {
  protected static final Logger LOGGER = LogManager.getLogger();
  
  public static final String ID_TAG = "id";
  
  public static final String PASSENGERS_TAG = "Passengers";
  
  private static final AtomicInteger ENTITY_COUNTER = new AtomicInteger();
  
  private static final List<ItemStack> EMPTY_LIST = Collections.emptyList();
  
  public static final int BOARDING_COOLDOWN = 60;
  
  public static final int TOTAL_AIR_SUPPLY = 300;
  
  public static final int MAX_ENTITY_TAG_COUNT = 1024;
  
  public static final double DELTA_AFFECTED_BY_BLOCKS_BELOW = 0.5000001D;
  
  public static final float BREATHING_DISTANCE_BELOW_EYES = 0.11111111F;
  
  public static final int BASE_TICKS_REQUIRED_TO_FREEZE = 140;
  
  public static final int FREEZE_HURT_FREQUENCY = 40;
  
  private static final AABB INITIAL_AABB = new AABB(0.0D, 0.0D, 0.0D, 0.0D, 0.0D, 0.0D);
  
  private static final double WATER_FLOW_SCALE = 0.014D;
  
  private static final double LAVA_FAST_FLOW_SCALE = 0.007D;
  
  private static final double LAVA_SLOW_FLOW_SCALE = 0.0023333333333333335D;
  
  public static final String UUID_TAG = "UUID";
  
  private static double viewScale = 1.0D;
  
  private final EntityType<?> type;
  
  private int id = ENTITY_COUNTER.incrementAndGet();
  
  public boolean blocksBuilding;
  
  private ImmutableList<Entity> passengers = ImmutableList.of();
  
  protected int boardingCooldown;
  
  @Nullable
  private Entity vehicle;
  
  public Level level;
  
  public double xo;
  
  public double yo;
  
  public double zo;
  
  private Vec3 position;
  
  private BlockPos blockPosition;
  
  private Vec3 deltaMovement = Vec3.ZERO;
  
  private float yRot;
  
  private float xRot;
  
  public float yRotO;
  
  public float xRotO;
  
  private AABB bb = INITIAL_AABB;
  
  protected boolean onGround;
  
  public boolean horizontalCollision;
  
  public boolean verticalCollision;
  
  public boolean hurtMarked;
  
  protected Vec3 stuckSpeedMultiplier = Vec3.ZERO;
  
  @Nullable
  private RemovalReason removalReason;
  
  public static final float DEFAULT_BB_WIDTH = 0.6F;
  
  public static final float DEFAULT_BB_HEIGHT = 1.8F;
  
  public float walkDistO;
  
  public float walkDist;
  
  public float moveDist;
  
  public float flyDist;
  
  public float fallDistance;
  
  private float nextStep = 1.0F;
  
  public double xOld;
  
  public double yOld;
  
  public double zOld;
  
  public float maxUpStep;
  
  public boolean noPhysics;
  
  protected final Random random = new Random();
  
  public int tickCount;
  
  private int remainingFireTicks = -getFireImmuneTicks();
  
  protected boolean wasTouchingWater;
  
  protected Object2DoubleMap<Tag<Fluid>> fluidHeight = (Object2DoubleMap<Tag<Fluid>>)new Object2DoubleArrayMap(2);
  
  protected boolean wasEyeInWater;
  
  @Nullable
  protected Tag<Fluid> fluidOnEyes;
  
  public int invulnerableTime;
  
  protected boolean firstTick = true;
  
  protected final SynchedEntityData entityData;
  
  protected static final EntityDataAccessor<Byte> DATA_SHARED_FLAGS_ID = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.BYTE);
  
  protected static final int FLAG_ONFIRE = 0;
  
  private static final int FLAG_SHIFT_KEY_DOWN = 1;
  
  private static final int FLAG_SPRINTING = 3;
  
  private static final int FLAG_SWIMMING = 4;
  
  private static final int FLAG_INVISIBLE = 5;
  
  protected static final int FLAG_GLOWING = 6;
  
  protected static final int FLAG_FALL_FLYING = 7;
  
  private static final EntityDataAccessor<Integer> DATA_AIR_SUPPLY_ID = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.INT);
  
  private static final EntityDataAccessor<Optional<Component>> DATA_CUSTOM_NAME = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.OPTIONAL_COMPONENT);
  
  private static final EntityDataAccessor<Boolean> DATA_CUSTOM_NAME_VISIBLE = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.BOOLEAN);
  
  private static final EntityDataAccessor<Boolean> DATA_SILENT = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.BOOLEAN);
  
  private static final EntityDataAccessor<Boolean> DATA_NO_GRAVITY = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.BOOLEAN);
  
  protected static final EntityDataAccessor<Pose> DATA_POSE = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.POSE);
  
  private static final EntityDataAccessor<Integer> DATA_TICKS_FROZEN = SynchedEntityData.defineId(Entity.class, EntityDataSerializers.INT);
  
  private EntityInLevelCallback levelCallback = EntityInLevelCallback.NULL;
  
  private Vec3 packetCoordinates;
  
  public boolean noCulling;
  
  public boolean hasImpulse;
  
  private int portalCooldown;
  
  protected boolean isInsidePortal;
  
  protected int portalTime;
  
  protected BlockPos portalEntrancePos;
  
  private boolean invulnerable;
  
  protected UUID uuid = Mth.createInsecureUUID(this.random);
  
  protected String stringUUID = this.uuid.toString();
  
  private boolean hasGlowingTag;
  
  private final Set<String> tags = Sets.newHashSet();
  
  private final double[] pistonDeltas = new double[] { 0.0D, 0.0D, 0.0D };
  
  private long pistonDeltasGameTime;
  
  private EntityDimensions dimensions;
  
  private float eyeHeight;
  
  public boolean isInPowderSnow;
  
  public boolean wasInPowderSnow;
  
  public boolean wasOnFire;
  
  private float crystalSoundIntensity;
  
  private int lastCrystalSoundPlayTick;
  
  private boolean hasVisualFire;
  
  public Entity(EntityType<?> param_0, Level param_1) {
    this.type = param_0;
    this.level = param_1;
    this.dimensions = param_0.getDimensions();
    this.position = Vec3.ZERO;
    this.blockPosition = BlockPos.ZERO;
    this.packetCoordinates = Vec3.ZERO;
    this.entityData = new SynchedEntityData(this);
    this.entityData.define(DATA_SHARED_FLAGS_ID, Byte.valueOf((byte)0));
    this.entityData.define(DATA_AIR_SUPPLY_ID, Integer.valueOf(getMaxAirSupply()));
    this.entityData.define(DATA_CUSTOM_NAME_VISIBLE, Boolean.valueOf(false));
    this.entityData.define(DATA_CUSTOM_NAME, Optional.empty());
    this.entityData.define(DATA_SILENT, Boolean.valueOf(false));
    this.entityData.define(DATA_NO_GRAVITY, Boolean.valueOf(false));
    this.entityData.define(DATA_POSE, Pose.STANDING);
    this.entityData.define(DATA_TICKS_FROZEN, Integer.valueOf(0));
    defineSynchedData();
    setPos(0.0D, 0.0D, 0.0D);
    this.eyeHeight = getEyeHeight(Pose.STANDING, this.dimensions);
  }
  
  public boolean isColliding(BlockPos param_0, BlockState param_1) {
    VoxelShape var_0 = param_1.getCollisionShape((BlockGetter)this.level, param_0, CollisionContext.of(this));
    VoxelShape var_1 = var_0.move(param_0.getX(), param_0.getY(), param_0.getZ());
    return Shapes.joinIsNotEmpty(var_1, Shapes.create(getBoundingBox()), BooleanOp.AND);
  }
  
  public int getTeamColor() {
    Team var_0 = getTeam();
    if (var_0 != null && var_0.getColor().getColor() != null)
      return var_0.getColor().getColor().intValue(); 
    return 16777215;
  }
  
  public boolean isSpectator() {
    return false;
  }
  
  public final void unRide() {
    if (isVehicle())
      ejectPassengers(); 
    if (isPassenger())
      stopRiding(); 
  }
  
  public void setPacketCoordinates(double param_0, double param_1, double param_2) {
    setPacketCoordinates(new Vec3(param_0, param_1, param_2));
  }
  
  public void setPacketCoordinates(Vec3 param_0) {
    this.packetCoordinates = param_0;
  }
  
  public Vec3 getPacketCoordinates() {
    return this.packetCoordinates;
  }
  
  public EntityType<?> getType() {
    return this.type;
  }
  
  public int getId() {
    return this.id;
  }
  
  public void setId(int param_0) {
    this.id = param_0;
  }
  
  public Set<String> getTags() {
    return this.tags;
  }
  
  public boolean addTag(String param_0) {
    if (this.tags.size() >= 1024)
      return false; 
    return this.tags.add(param_0);
  }
  
  public boolean removeTag(String param_0) {
    return this.tags.remove(param_0);
  }
  
  public void kill() {
    remove(RemovalReason.KILLED);
  }
  
  public final void discard() {
    remove(RemovalReason.DISCARDED);
  }
  
  public SynchedEntityData getEntityData() {
    return this.entityData;
  }
  
  public boolean equals(Object param_0) {
    if (param_0 instanceof Entity)
      return (((Entity)param_0).id == this.id); 
    return false;
  }
  
  public int hashCode() {
    return this.id;
  }
  
  public void remove(RemovalReason param_0) {
    setRemoved(param_0);
    if (param_0 == RemovalReason.KILLED)
      gameEvent(GameEvent.ENTITY_KILLED); 
  }
  
  public void onClientRemoval() {}
  
  public void setPose(Pose param_0) {
    this.entityData.set(DATA_POSE, param_0);
  }
  
  public Pose getPose() {
    return (Pose)this.entityData.get(DATA_POSE);
  }
  
  public boolean closerThan(Entity param_0, double param_1) {
    double var_0 = param_0.position.x - this.position.x;
    double var_1 = param_0.position.y - this.position.y;
    double var_2 = param_0.position.z - this.position.z;
    return (var_0 * var_0 + var_1 * var_1 + var_2 * var_2 < param_1 * param_1);
  }
  
  protected void setRot(float param_0, float param_1) {
    setYRot(param_0 % 360.0F);
    setXRot(param_1 % 360.0F);
  }
  
  public final void setPos(Vec3 param_0) {
    setPos(param_0.x(), param_0.y(), param_0.z());
  }
  
  public void setPos(double param_0, double param_1, double param_2) {
    setPosRaw(param_0, param_1, param_2);
    setBoundingBox(makeBoundingBox());
  }
  
  protected AABB makeBoundingBox() {
    return this.dimensions.makeBoundingBox(this.position);
  }
  
  protected void reapplyPosition() {
    setPos(this.position.x, this.position.y, this.position.z);
  }
  
  public void turn(double param_0, double param_1) {
    float var_0 = (float)param_1 * 0.15F;
    float var_1 = (float)param_0 * 0.15F;
    setXRot(getXRot() + var_0);
    setYRot(getYRot() + var_1);
    setXRot(Mth.clamp(getXRot(), -90.0F, 90.0F));
    this.xRotO += var_0;
    this.yRotO += var_1;
    this.xRotO = Mth.clamp(this.xRotO, -90.0F, 90.0F);
    if (this.vehicle != null)
      this.vehicle.onPassengerTurned(this); 
  }
  
  public void tick() {
    baseTick();
  }
  
  public void baseTick() {
    this.level.getProfiler().push("entityBaseTick");
    if (isPassenger() && getVehicle().isRemoved())
      stopRiding(); 
    if (this.boardingCooldown > 0)
      this.boardingCooldown--; 
    this.walkDistO = this.walkDist;
    this.xRotO = getXRot();
    this.yRotO = getYRot();
    handleNetherPortal();
    if (canSpawnSprintParticle())
      spawnSprintParticle(); 
    this.wasInPowderSnow = this.isInPowderSnow;
    this.isInPowderSnow = false;
    updateInWaterStateAndDoFluidPushing();
    updateFluidOnEyes();
    updateSwimming();
    if (this.level.isClientSide) {
      clearFire();
    } else if (this.remainingFireTicks > 0) {
      if (fireImmune()) {
        setRemainingFireTicks(this.remainingFireTicks - 4);
        if (this.remainingFireTicks < 0)
          clearFire(); 
      } else {
        if (this.remainingFireTicks % 20 == 0 && !isInLava())
          hurt(DamageSource.ON_FIRE, 1.0F); 
        setRemainingFireTicks(this.remainingFireTicks - 1);
      } 
      if (getTicksFrozen() > 0) {
        setTicksFrozen(0);
        this.level.levelEvent(null, 1009, this.blockPosition, 1);
      } 
    } 
    if (isInLava()) {
      lavaHurt();
      this.fallDistance *= 0.5F;
    } 
    checkOutOfWorld();
    if (!this.level.isClientSide)
      setSharedFlagOnFire((this.remainingFireTicks > 0)); 
    this.firstTick = false;
    this.level.getProfiler().pop();
  }
  
  public void setSharedFlagOnFire(boolean param_0) {
    setSharedFlag(0, (param_0 || this.hasVisualFire));
  }
  
  public void checkOutOfWorld() {
    if (getY() < (this.level.getMinBuildHeight() - 64))
      outOfWorld(); 
  }
  
  public void setPortalCooldown() {
    this.portalCooldown = getDimensionChangingDelay();
  }
  
  public boolean isOnPortalCooldown() {
    return (this.portalCooldown > 0);
  }
  
  protected void processPortalCooldown() {
    if (isOnPortalCooldown())
      this.portalCooldown--; 
  }
  
  public int getPortalWaitTime() {
    return 0;
  }
  
  public void lavaHurt() {
    if (fireImmune())
      return; 
    setSecondsOnFire(15);
    if (hurt(DamageSource.LAVA, 4.0F))
      playSound(SoundEvents.GENERIC_BURN, 0.4F, 2.0F + this.random.nextFloat() * 0.4F); 
  }
  
  public void setSecondsOnFire(int param_0) {
    int var_0 = param_0 * 20;
    if (this instanceof LivingEntity)
      var_0 = ProtectionEnchantment.getFireAfterDampener((LivingEntity)this, var_0); 
    if (this.remainingFireTicks < var_0)
      setRemainingFireTicks(var_0); 
  }
  
  public void setRemainingFireTicks(int param_0) {
    this.remainingFireTicks = param_0;
  }
  
  public int getRemainingFireTicks() {
    return this.remainingFireTicks;
  }
  
  public void clearFire() {
    setRemainingFireTicks(0);
  }
  
  protected void outOfWorld() {
    discard();
  }
  
  public boolean isFree(double param_0, double param_1, double param_2) {
    return isFree(getBoundingBox().move(param_0, param_1, param_2));
  }
  
  private boolean isFree(AABB param_0) {
    return (this.level.noCollision(this, param_0) && !this.level.containsAnyLiquid(param_0));
  }
  
  public void setOnGround(boolean param_0) {
    this.onGround = param_0;
  }
  
  public boolean isOnGround() {
    return this.onGround;
  }
  
  public void move(MoverType param_0, Vec3 param_1) {
    if (this.noPhysics) {
      setPos(getX() + param_1.x, getY() + param_1.y, getZ() + param_1.z);
      return;
    } 
    this.wasOnFire = isOnFire();
    if (param_0 == MoverType.PISTON) {
      param_1 = limitPistonMovement(param_1);
      if (param_1.equals(Vec3.ZERO))
        return; 
    } 
    this.level.getProfiler().push("move");
    if (this.stuckSpeedMultiplier.lengthSqr() > 1.0E-7D) {
      param_1 = param_1.multiply(this.stuckSpeedMultiplier);
      this.stuckSpeedMultiplier = Vec3.ZERO;
      setDeltaMovement(Vec3.ZERO);
    } 
    param_1 = maybeBackOffFromEdge(param_1, param_0);
    Vec3 var_0 = collide(param_1);
    if (var_0.lengthSqr() > 1.0E-7D)
      setPos(getX() + var_0.x, getY() + var_0.y, getZ() + var_0.z); 
    this.level.getProfiler().pop();
    this.level.getProfiler().push("rest");
    this.horizontalCollision = (!Mth.equal(param_1.x, var_0.x) || !Mth.equal(param_1.z, var_0.z));
    this.verticalCollision = (param_1.y != var_0.y);
    this.onGround = (this.verticalCollision && param_1.y < 0.0D);
    BlockPos var_1 = getOnPos();
    BlockState var_2 = this.level.getBlockState(var_1);
    checkFallDamage(var_0.y, this.onGround, var_2, var_1);
    if (isRemoved()) {
      this.level.getProfiler().pop();
      return;
    } 
    Vec3 var_3 = getDeltaMovement();
    if (param_1.x != var_0.x)
      setDeltaMovement(0.0D, var_3.y, var_3.z); 
    if (param_1.z != var_0.z)
      setDeltaMovement(var_3.x, var_3.y, 0.0D); 
    Block var_4 = var_2.getBlock();
    if (param_1.y != var_0.y)
      var_4.updateEntityAfterFallOn((BlockGetter)this.level, this); 
    if (this.onGround && !isSteppingCarefully())
      var_4.stepOn(this.level, var_1, var_2, this); 
    MovementEmission var_5 = getMovementEmission();
    if (var_5.emitsAnything() && !isPassenger()) {
      double var_6 = var_0.x;
      double var_7 = var_0.y;
      double var_8 = var_0.z;
      this.flyDist = (float)(this.flyDist + var_0.length() * 0.6D);
      if (!var_2.is((Tag)BlockTags.CLIMBABLE) && !var_2.is(Blocks.POWDER_SNOW))
        var_7 = 0.0D; 
      this.walkDist += (float)var_0.horizontalDistance() * 0.6F;
      this.moveDist += (float)Math.sqrt(var_6 * var_6 + var_7 * var_7 + var_8 * var_8) * 0.6F;
      if (this.moveDist > this.nextStep && !var_2.isAir()) {
        this.nextStep = nextStep();
        if (isInWater()) {
          if (var_5.emitsSounds()) {
            Entity var_9 = (isVehicle() && getControllingPassenger() != null) ? getControllingPassenger() : this;
            float var_10 = (var_9 == this) ? 0.35F : 0.4F;
            Vec3 var_11 = var_9.getDeltaMovement();
            float var_12 = Math.min(1.0F, (float)Math.sqrt(var_11.x * var_11.x * 0.20000000298023224D + var_11.y * var_11.y + var_11.z * var_11.z * 0.20000000298023224D) * var_10);
            playSwimSound(var_12);
          } 
          if (var_5.emitsEvents())
            gameEvent(GameEvent.SWIM); 
        } else {
          if (var_5.emitsSounds()) {
            playAmethystStepSound(var_2);
            playStepSound(var_1, var_2);
          } 
          if (var_5.emitsEvents() && !var_2.is((Tag)BlockTags.OCCLUDES_VIBRATION_SIGNALS))
            gameEvent(GameEvent.STEP); 
        } 
      } else if (var_2.isAir()) {
        processFlappingMovement();
      } 
    } 
    tryCheckInsideBlocks();
    float var_13 = getBlockSpeedFactor();
    setDeltaMovement(getDeltaMovement().multiply(var_13, 1.0D, var_13));
    if (this.level.getBlockStatesIfLoaded(getBoundingBox().deflate(1.0E-6D)).noneMatch(param_0 -> (param_0.is((Tag)BlockTags.FIRE) || param_0.is(Blocks.LAVA)))) {
      if (this.remainingFireTicks <= 0)
        setRemainingFireTicks(-getFireImmuneTicks()); 
      if (this.wasOnFire && (this.isInPowderSnow || isInWaterRainOrBubble()))
        playEntityOnFireExtinguishedSound(); 
    } 
    if (isOnFire() && (this.isInPowderSnow || isInWaterRainOrBubble()))
      setRemainingFireTicks(-getFireImmuneTicks()); 
    this.level.getProfiler().pop();
  }
  
  protected void tryCheckInsideBlocks() {
    try {
      checkInsideBlocks();
    } catch (Throwable var_0) {
      CrashReport var_1 = CrashReport.forThrowable(var_0, "Checking entity block collision");
      CrashReportCategory var_2 = var_1.addCategory("Entity being checked for collision");
      fillCrashReportCategory(var_2);
      throw new ReportedException(var_1);
    } 
  }
  
  protected void playEntityOnFireExtinguishedSound() {
    playSound(SoundEvents.GENERIC_EXTINGUISH_FIRE, 0.7F, 1.6F + (this.random.nextFloat() - this.random.nextFloat()) * 0.4F);
  }
  
  protected void processFlappingMovement() {
    if (isFlapping()) {
      onFlap();
      if (getMovementEmission().emitsEvents())
        gameEvent(GameEvent.FLAP); 
    } 
  }
  
  public BlockPos getOnPos() {
    int var_0 = Mth.floor(this.position.x);
    int var_1 = Mth.floor(this.position.y - 0.20000000298023224D);
    int var_2 = Mth.floor(this.position.z);
    BlockPos var_3 = new BlockPos(var_0, var_1, var_2);
    if (this.level.getBlockState(var_3).isAir()) {
      BlockPos var_4 = var_3.below();
      BlockState var_5 = this.level.getBlockState(var_4);
      if (var_5.is((Tag)BlockTags.FENCES) || var_5.is((Tag)BlockTags.WALLS) || var_5.getBlock() instanceof net.minecraft.world.level.block.FenceGateBlock)
        return var_4; 
    } 
    return var_3;
  }
  
  protected float getBlockJumpFactor() {
    float var_0 = this.level.getBlockState(blockPosition()).getBlock().getJumpFactor();
    float var_1 = this.level.getBlockState(getBlockPosBelowThatAffectsMyMovement()).getBlock().getJumpFactor();
    return (var_0 == 1.0D) ? var_1 : var_0;
  }
  
  protected float getBlockSpeedFactor() {
    BlockState var_0 = this.level.getBlockState(blockPosition());
    float var_1 = var_0.getBlock().getSpeedFactor();
    if (var_0.is(Blocks.WATER) || var_0.is(Blocks.BUBBLE_COLUMN))
      return var_1; 
    return (var_1 == 1.0D) ? this.level.getBlockState(getBlockPosBelowThatAffectsMyMovement()).getBlock().getSpeedFactor() : var_1;
  }
  
  protected BlockPos getBlockPosBelowThatAffectsMyMovement() {
    return new BlockPos(this.position.x, (getBoundingBox()).minY - 0.5000001D, this.position.z);
  }
  
  protected Vec3 maybeBackOffFromEdge(Vec3 param_0, MoverType param_1) {
    return param_0;
  }
  
  protected Vec3 limitPistonMovement(Vec3 param_0) {
    if (param_0.lengthSqr() <= 1.0E-7D)
      return param_0; 
    long var_0 = this.level.getGameTime();
    if (var_0 != this.pistonDeltasGameTime) {
      Arrays.fill(this.pistonDeltas, 0.0D);
      this.pistonDeltasGameTime = var_0;
    } 
    if (param_0.x != 0.0D) {
      double var_1 = applyPistonMovementRestriction(Direction.Axis.X, param_0.x);
      return (Math.abs(var_1) <= 9.999999747378752E-6D) ? Vec3.ZERO : new Vec3(var_1, 0.0D, 0.0D);
    } 
    if (param_0.y != 0.0D) {
      double var_2 = applyPistonMovementRestriction(Direction.Axis.Y, param_0.y);
      return (Math.abs(var_2) <= 9.999999747378752E-6D) ? Vec3.ZERO : new Vec3(0.0D, var_2, 0.0D);
    } 
    if (param_0.z != 0.0D) {
      double var_3 = applyPistonMovementRestriction(Direction.Axis.Z, param_0.z);
      return (Math.abs(var_3) <= 9.999999747378752E-6D) ? Vec3.ZERO : new Vec3(0.0D, 0.0D, var_3);
    } 
    return Vec3.ZERO;
  }
  
  private double applyPistonMovementRestriction(Direction.Axis param_0, double param_1) {
    int var_0 = param_0.ordinal();
    double var_1 = Mth.clamp(param_1 + this.pistonDeltas[var_0], -0.51D, 0.51D);
    param_1 = var_1 - this.pistonDeltas[var_0];
    this.pistonDeltas[var_0] = var_1;
    return param_1;
  }
  
  private Vec3 collide(Vec3 param_0) {
    AABB var_0 = getBoundingBox();
    CollisionContext var_1 = CollisionContext.of(this);
    VoxelShape var_2 = this.level.getWorldBorder().getCollisionShape();
    Stream<VoxelShape> var_3 = Shapes.joinIsNotEmpty(var_2, Shapes.create(var_0.deflate(1.0E-7D)), BooleanOp.AND) ? Stream.<VoxelShape>empty() : Stream.<VoxelShape>of(var_2);
    Stream<VoxelShape> var_4 = this.level.getEntityCollisions(this, var_0.expandTowards(param_0), param_0 -> true);
    RewindableStream<VoxelShape> var_5 = new RewindableStream(Stream.concat(var_4, var_3));
    Vec3 var_6 = (param_0.lengthSqr() == 0.0D) ? param_0 : collideBoundingBoxHeuristically(this, param_0, var_0, this.level, var_1, var_5);
    boolean var_7 = (param_0.x != var_6.x);
    boolean var_8 = (param_0.y != var_6.y);
    boolean var_9 = (param_0.z != var_6.z);
    boolean var_10 = (this.onGround || (var_8 && param_0.y < 0.0D));
    if (this.maxUpStep > 0.0F && var_10 && (var_7 || var_9)) {
      Vec3 var_11 = collideBoundingBoxHeuristically(this, new Vec3(param_0.x, this.maxUpStep, param_0.z), var_0, this.level, var_1, var_5);
      Vec3 var_12 = collideBoundingBoxHeuristically(this, new Vec3(0.0D, this.maxUpStep, 0.0D), var_0.expandTowards(param_0.x, 0.0D, param_0.z), this.level, var_1, var_5);
      if (var_12.y < this.maxUpStep) {
        Vec3 var_13 = collideBoundingBoxHeuristically(this, new Vec3(param_0.x, 0.0D, param_0.z), var_0.move(var_12), this.level, var_1, var_5).add(var_12);
        if (var_13.horizontalDistanceSqr() > var_11.horizontalDistanceSqr())
          var_11 = var_13; 
      } 
      if (var_11.horizontalDistanceSqr() > var_6.horizontalDistanceSqr())
        return var_11.add(collideBoundingBoxHeuristically(this, new Vec3(0.0D, -var_11.y + param_0.y, 0.0D), var_0.move(var_11), this.level, var_1, var_5)); 
    } 
    return var_6;
  }
  
  public static Vec3 collideBoundingBoxHeuristically(@Nullable Entity param_0, Vec3 param_1, AABB param_2, Level param_3, CollisionContext param_4, RewindableStream<VoxelShape> param_5) {
    boolean var_0 = (param_1.x == 0.0D);
    boolean var_1 = (param_1.y == 0.0D);
    boolean var_2 = (param_1.z == 0.0D);
    if ((var_0 && var_1) || (var_0 && var_2) || (var_1 && var_2))
      return collideBoundingBox(param_1, param_2, (LevelReader)param_3, param_4, param_5); 
    RewindableStream<VoxelShape> var_3 = new RewindableStream(Stream.concat(param_5
          .getStream(), param_3
          .getBlockCollisions(param_0, param_2.expandTowards(param_1))));
    return collideBoundingBoxLegacy(param_1, param_2, var_3);
  }
  
  public static Vec3 collideBoundingBoxLegacy(Vec3 param_0, AABB param_1, RewindableStream<VoxelShape> param_2) {
    double var_0 = param_0.x;
    double var_1 = param_0.y;
    double var_2 = param_0.z;
    if (var_1 != 0.0D) {
      var_1 = Shapes.collide(Direction.Axis.Y, param_1, param_2.getStream(), var_1);
      if (var_1 != 0.0D)
        param_1 = param_1.move(0.0D, var_1, 0.0D); 
    } 
    boolean var_3 = (Math.abs(var_0) < Math.abs(var_2));
    if (var_3 && var_2 != 0.0D) {
      var_2 = Shapes.collide(Direction.Axis.Z, param_1, param_2.getStream(), var_2);
      if (var_2 != 0.0D)
        param_1 = param_1.move(0.0D, 0.0D, var_2); 
    } 
    if (var_0 != 0.0D) {
      var_0 = Shapes.collide(Direction.Axis.X, param_1, param_2.getStream(), var_0);
      if (!var_3 && var_0 != 0.0D)
        param_1 = param_1.move(var_0, 0.0D, 0.0D); 
    } 
    if (!var_3 && var_2 != 0.0D)
      var_2 = Shapes.collide(Direction.Axis.Z, param_1, param_2.getStream(), var_2); 
    return new Vec3(var_0, var_1, var_2);
  }
  
  public static Vec3 collideBoundingBox(Vec3 param_0, AABB param_1, LevelReader param_2, CollisionContext param_3, RewindableStream<VoxelShape> param_4) {
    double var_0 = param_0.x;
    double var_1 = param_0.y;
    double var_2 = param_0.z;
    if (var_1 != 0.0D) {
      var_1 = Shapes.collide(Direction.Axis.Y, param_1, param_2, var_1, param_3, param_4.getStream());
      if (var_1 != 0.0D)
        param_1 = param_1.move(0.0D, var_1, 0.0D); 
    } 
    boolean var_3 = (Math.abs(var_0) < Math.abs(var_2));
    if (var_3 && var_2 != 0.0D) {
      var_2 = Shapes.collide(Direction.Axis.Z, param_1, param_2, var_2, param_3, param_4.getStream());
      if (var_2 != 0.0D)
        param_1 = param_1.move(0.0D, 0.0D, var_2); 
    } 
    if (var_0 != 0.0D) {
      var_0 = Shapes.collide(Direction.Axis.X, param_1, param_2, var_0, param_3, param_4.getStream());
      if (!var_3 && var_0 != 0.0D)
        param_1 = param_1.move(var_0, 0.0D, 0.0D); 
    } 
    if (!var_3 && var_2 != 0.0D)
      var_2 = Shapes.collide(Direction.Axis.Z, param_1, param_2, var_2, param_3, param_4.getStream()); 
    return new Vec3(var_0, var_1, var_2);
  }
  
  protected float nextStep() {
    return ((int)this.moveDist + 1);
  }
  
  protected SoundEvent getSwimSound() {
    return SoundEvents.GENERIC_SWIM;
  }
  
  protected SoundEvent getSwimSplashSound() {
    return SoundEvents.GENERIC_SPLASH;
  }
  
  protected SoundEvent getSwimHighSpeedSplashSound() {
    return SoundEvents.GENERIC_SPLASH;
  }
  
  protected void checkInsideBlocks() {
    AABB var_0 = getBoundingBox();
    BlockPos var_1 = new BlockPos(var_0.minX + 0.001D, var_0.minY + 0.001D, var_0.minZ + 0.001D);
    BlockPos var_2 = new BlockPos(var_0.maxX - 0.001D, var_0.maxY - 0.001D, var_0.maxZ - 0.001D);
    if (this.level.hasChunksAt(var_1, var_2)) {
      BlockPos.MutableBlockPos var_3 = new BlockPos.MutableBlockPos();
      for (int var_4 = var_1.getX(); var_4 <= var_2.getX(); var_4++) {
        for (int var_5 = var_1.getY(); var_5 <= var_2.getY(); var_5++) {
          for (int var_6 = var_1.getZ(); var_6 <= var_2.getZ(); var_6++) {
            var_3.set(var_4, var_5, var_6);
            BlockState var_7 = this.level.getBlockState((BlockPos)var_3);
            try {
              var_7.entityInside(this.level, (BlockPos)var_3, this);
              onInsideBlock(var_7);
            } catch (Throwable var_8) {
              CrashReport var_9 = CrashReport.forThrowable(var_8, "Colliding entity with block");
              CrashReportCategory var_10 = var_9.addCategory("Block being collided with");
              CrashReportCategory.populateBlockDetails(var_10, (LevelHeightAccessor)this.level, (BlockPos)var_3, var_7);
              throw new ReportedException(var_9);
            } 
          } 
        } 
      } 
    } 
  }
  
  protected void onInsideBlock(BlockState param_0) {}
  
  public void gameEvent(GameEvent param_0, @Nullable Entity param_1, BlockPos param_2) {
    this.level.gameEvent(param_1, param_0, param_2);
  }
  
  public void gameEvent(GameEvent param_0, @Nullable Entity param_1) {
    gameEvent(param_0, param_1, this.blockPosition);
  }
  
  public void gameEvent(GameEvent param_0, BlockPos param_1) {
    gameEvent(param_0, this, param_1);
  }
  
  public void gameEvent(GameEvent param_0) {
    gameEvent(param_0, this.blockPosition);
  }
  
  protected void playStepSound(BlockPos param_0, BlockState param_1) {
    if (param_1.getMaterial().isLiquid())
      return; 
    BlockState var_0 = this.level.getBlockState(param_0.above());
    SoundType var_1 = var_0.is((Tag)BlockTags.INSIDE_STEP_SOUND_BLOCKS) ? var_0.getSoundType() : param_1.getSoundType();
    playSound(var_1.getStepSound(), var_1.getVolume() * 0.15F, var_1.getPitch());
  }
  
  private void playAmethystStepSound(BlockState param_0) {
    if (param_0.is((Tag)BlockTags.CRYSTAL_SOUND_BLOCKS) && this.tickCount >= this.lastCrystalSoundPlayTick + 20) {
      this.crystalSoundIntensity = (float)(this.crystalSoundIntensity * Math.pow(0.996999979019165D, (this.tickCount - this.lastCrystalSoundPlayTick)));
      this.crystalSoundIntensity = Math.min(1.0F, this.crystalSoundIntensity + 0.07F);
      float var_0 = 0.5F + this.crystalSoundIntensity * this.random.nextFloat() * 1.2F;
      float var_1 = 0.1F + this.crystalSoundIntensity * 1.2F;
      playSound(SoundEvents.AMETHYST_BLOCK_CHIME, var_1, var_0);
      this.lastCrystalSoundPlayTick = this.tickCount;
    } 
  }
  
  protected void playSwimSound(float param_0) {
    playSound(getSwimSound(), param_0, 1.0F + (this.random.nextFloat() - this.random.nextFloat()) * 0.4F);
  }
  
  protected void onFlap() {}
  
  protected boolean isFlapping() {
    return false;
  }
  
  public void playSound(SoundEvent param_0, float param_1, float param_2) {
    if (!isSilent())
      this.level.playSound(null, getX(), getY(), getZ(), param_0, getSoundSource(), param_1, param_2); 
  }
  
  public boolean isSilent() {
    return ((Boolean)this.entityData.get(DATA_SILENT)).booleanValue();
  }
  
  public void setSilent(boolean param_0) {
    this.entityData.set(DATA_SILENT, Boolean.valueOf(param_0));
  }
  
  public boolean isNoGravity() {
    return ((Boolean)this.entityData.get(DATA_NO_GRAVITY)).booleanValue();
  }
  
  public void setNoGravity(boolean param_0) {
    this.entityData.set(DATA_NO_GRAVITY, Boolean.valueOf(param_0));
  }
  
  protected MovementEmission getMovementEmission() {
    return MovementEmission.ALL;
  }
  
  public boolean occludesVibrations() {
    return false;
  }
  
  protected void checkFallDamage(double param_0, boolean param_1, BlockState param_2, BlockPos param_3) {
    if (param_1) {
      if (this.fallDistance > 0.0F) {
        param_2.getBlock().fallOn(this.level, param_2, param_3, this, this.fallDistance);
        if (!param_2.is((Tag)BlockTags.OCCLUDES_VIBRATION_SIGNALS))
          gameEvent(GameEvent.HIT_GROUND); 
      } 
      this.fallDistance = 0.0F;
    } else if (param_0 < 0.0D) {
      this.fallDistance = (float)(this.fallDistance - param_0);
    } 
  }
  
  public boolean fireImmune() {
    return getType().fireImmune();
  }
  
  public boolean causeFallDamage(float param_0, float param_1, DamageSource param_2) {
    if (isVehicle())
      for (Entity var_0 : getPassengers())
        var_0.causeFallDamage(param_0, param_1, param_2);  
    return false;
  }
  
  public boolean isInWater() {
    return this.wasTouchingWater;
  }
  
  private boolean isInRain() {
    BlockPos var_0 = blockPosition();
    return (this.level.isRainingAt(var_0) || this.level.isRainingAt(new BlockPos(var_0.getX(), (getBoundingBox()).maxY, var_0.getZ())));
  }
  
  private boolean isInBubbleColumn() {
    return this.level.getBlockState(blockPosition()).is(Blocks.BUBBLE_COLUMN);
  }
  
  public boolean isInWaterOrRain() {
    return (isInWater() || isInRain());
  }
  
  public boolean isInWaterRainOrBubble() {
    return (isInWater() || isInRain() || isInBubbleColumn());
  }
  
  public boolean isInWaterOrBubble() {
    return (isInWater() || isInBubbleColumn());
  }
  
  public boolean isUnderWater() {
    return (this.wasEyeInWater && isInWater());
  }
  
  public void updateSwimming() {
    if (isSwimming()) {
      setSwimming((isSprinting() && isInWater() && !isPassenger()));
    } else {
      setSwimming((isSprinting() && isUnderWater() && !isPassenger() && this.level.getFluidState(this.blockPosition).is((Tag)FluidTags.WATER)));
    } 
  }
  
  protected boolean updateInWaterStateAndDoFluidPushing() {
    this.fluidHeight.clear();
    updateInWaterStateAndDoWaterCurrentPushing();
    double var_0 = this.level.dimensionType().ultraWarm() ? 0.007D : 0.0023333333333333335D;
    boolean var_1 = updateFluidHeightAndDoFluidPushing((Tag<Fluid>)FluidTags.LAVA, var_0);
    return (isInWater() || var_1);
  }
  
  void updateInWaterStateAndDoWaterCurrentPushing() {
    if (getVehicle() instanceof Boat) {
      this.wasTouchingWater = false;
    } else if (updateFluidHeightAndDoFluidPushing((Tag<Fluid>)FluidTags.WATER, 0.014D)) {
      if (!this.wasTouchingWater && !this.firstTick)
        doWaterSplashEffect(); 
      this.fallDistance = 0.0F;
      this.wasTouchingWater = true;
      clearFire();
    } else {
      this.wasTouchingWater = false;
    } 
  }
  
  private void updateFluidOnEyes() {
    this.wasEyeInWater = isEyeInFluid((Tag<Fluid>)FluidTags.WATER);
    this.fluidOnEyes = null;
    double var_0 = getEyeY() - 0.1111111119389534D;
    Entity var_1 = getVehicle();
    if (var_1 instanceof Boat) {
      Boat var_2 = (Boat)var_1;
      if (!var_2.isUnderWater() && (var_2.getBoundingBox()).maxY >= var_0 && (var_2.getBoundingBox()).minY <= var_0)
        return; 
    } 
    BlockPos var_3 = new BlockPos(getX(), var_0, getZ());
    FluidState var_4 = this.level.getFluidState(var_3);
    for (Tag<Fluid> var_5 : (Iterable<Tag<Fluid>>)FluidTags.getStaticTags()) {
      if (var_4.is(var_5)) {
        double var_6 = (var_3.getY() + var_4.getHeight((BlockGetter)this.level, var_3));
        if (var_6 > var_0)
          this.fluidOnEyes = var_5; 
        return;
      } 
    } 
  }
  
  protected void doWaterSplashEffect() {
    Entity var_0 = (isVehicle() && getControllingPassenger() != null) ? getControllingPassenger() : this;
    float var_1 = (var_0 == this) ? 0.2F : 0.9F;
    Vec3 var_2 = var_0.getDeltaMovement();
    float var_3 = Math.min(1.0F, (float)Math.sqrt(var_2.x * var_2.x * 0.20000000298023224D + var_2.y * var_2.y + var_2.z * var_2.z * 0.20000000298023224D) * var_1);
    if (var_3 < 0.25F) {
      playSound(getSwimSplashSound(), var_3, 1.0F + (this.random.nextFloat() - this.random.nextFloat()) * 0.4F);
    } else {
      playSound(getSwimHighSpeedSplashSound(), var_3, 1.0F + (this.random.nextFloat() - this.random.nextFloat()) * 0.4F);
    } 
    float var_4 = Mth.floor(getY());
    for (int var_5 = 0; var_5 < 1.0F + this.dimensions.width * 20.0F; var_5++) {
      double var_6 = (this.random.nextDouble() * 2.0D - 1.0D) * this.dimensions.width;
      double var_7 = (this.random.nextDouble() * 2.0D - 1.0D) * this.dimensions.width;
      this.level.addParticle((ParticleOptions)ParticleTypes.BUBBLE, getX() + var_6, (var_4 + 1.0F), getZ() + var_7, var_2.x, var_2.y - this.random.nextDouble() * 0.20000000298023224D, var_2.z);
    } 
    for (int var_8 = 0; var_8 < 1.0F + this.dimensions.width * 20.0F; var_8++) {
      double var_9 = (this.random.nextDouble() * 2.0D - 1.0D) * this.dimensions.width;
      double var_10 = (this.random.nextDouble() * 2.0D - 1.0D) * this.dimensions.width;
      this.level.addParticle((ParticleOptions)ParticleTypes.SPLASH, getX() + var_9, (var_4 + 1.0F), getZ() + var_10, var_2.x, var_2.y, var_2.z);
    } 
    gameEvent(GameEvent.SPLASH);
  }
  
  protected BlockState getBlockStateOn() {
    return this.level.getBlockState(getOnPos());
  }
  
  public boolean canSpawnSprintParticle() {
    return (isSprinting() && !isInWater() && !isSpectator() && !isCrouching() && !isInLava() && isAlive());
  }
  
  protected void spawnSprintParticle() {
    int var_0 = Mth.floor(getX());
    int var_1 = Mth.floor(getY() - 0.20000000298023224D);
    int var_2 = Mth.floor(getZ());
    BlockPos var_3 = new BlockPos(var_0, var_1, var_2);
    BlockState var_4 = this.level.getBlockState(var_3);
    if (var_4.getRenderShape() != RenderShape.INVISIBLE) {
      Vec3 var_5 = getDeltaMovement();
      this.level.addParticle((ParticleOptions)new BlockParticleOption(ParticleTypes.BLOCK, var_4), getX() + (this.random.nextDouble() - 0.5D) * this.dimensions.width, getY() + 0.1D, getZ() + (this.random.nextDouble() - 0.5D) * this.dimensions.width, var_5.x * -4.0D, 1.5D, var_5.z * -4.0D);
    } 
  }
  
  public boolean isEyeInFluid(Tag<Fluid> param_0) {
    return (this.fluidOnEyes == param_0);
  }
  
  public boolean isInLava() {
    return (!this.firstTick && this.fluidHeight.getDouble(FluidTags.LAVA) > 0.0D);
  }
  
  public void moveRelative(float param_0, Vec3 param_1) {
    Vec3 var_0 = getInputVector(param_1, param_0, getYRot());
    setDeltaMovement(getDeltaMovement().add(var_0));
  }
  
  private static Vec3 getInputVector(Vec3 param_0, float param_1, float param_2) {
    double var_0 = param_0.lengthSqr();
    if (var_0 < 1.0E-7D)
      return Vec3.ZERO; 
    Vec3 var_1 = ((var_0 > 1.0D) ? param_0.normalize() : param_0).scale(param_1);
    float var_2 = Mth.sin(param_2 * 0.017453292F);
    float var_3 = Mth.cos(param_2 * 0.017453292F);
    return new Vec3(var_1.x * var_3 - var_1.z * var_2, var_1.y, var_1.z * var_3 + var_1.x * var_2);
  }
  
  public float getBrightness() {
    if (this.level.hasChunkAt(getBlockX(), getBlockZ()))
      return this.level.getBrightness(new BlockPos(getX(), getEyeY(), getZ())); 
    return 0.0F;
  }
  
  public void absMoveTo(double param_0, double param_1, double param_2, float param_3, float param_4) {
    absMoveTo(param_0, param_1, param_2);
    setYRot(param_3 % 360.0F);
    setXRot(Mth.clamp(param_4, -90.0F, 90.0F) % 360.0F);
    this.yRotO = getYRot();
    this.xRotO = getXRot();
  }
  
  public void absMoveTo(double param_0, double param_1, double param_2) {
    double var_0 = Mth.clamp(param_0, -3.0E7D, 3.0E7D);
    double var_1 = Mth.clamp(param_2, -3.0E7D, 3.0E7D);
    this.xo = var_0;
    this.yo = param_1;
    this.zo = var_1;
    setPos(var_0, param_1, var_1);
  }
  
  public void moveTo(Vec3 param_0) {
    moveTo(param_0.x, param_0.y, param_0.z);
  }
  
  public void moveTo(double param_0, double param_1, double param_2) {
    moveTo(param_0, param_1, param_2, getYRot(), getXRot());
  }
  
  public void moveTo(BlockPos param_0, float param_1, float param_2) {
    moveTo(param_0.getX() + 0.5D, param_0.getY(), param_0.getZ() + 0.5D, param_1, param_2);
  }
  
  public void moveTo(double param_0, double param_1, double param_2, float param_3, float param_4) {
    setPosRaw(param_0, param_1, param_2);
    setYRot(param_3);
    setXRot(param_4);
    setOldPosAndRot();
    reapplyPosition();
  }
  
  public final void setOldPosAndRot() {
    double var_0 = getX();
    double var_1 = getY();
    double var_2 = getZ();
    this.xo = var_0;
    this.yo = var_1;
    this.zo = var_2;
    this.xOld = var_0;
    this.yOld = var_1;
    this.zOld = var_2;
    this.yRotO = getYRot();
    this.xRotO = getXRot();
  }
  
  public float distanceTo(Entity param_0) {
    float var_0 = (float)(getX() - param_0.getX());
    float var_1 = (float)(getY() - param_0.getY());
    float var_2 = (float)(getZ() - param_0.getZ());
    return Mth.sqrt(var_0 * var_0 + var_1 * var_1 + var_2 * var_2);
  }
  
  public double distanceToSqr(double param_0, double param_1, double param_2) {
    double var_0 = getX() - param_0;
    double var_1 = getY() - param_1;
    double var_2 = getZ() - param_2;
    return var_0 * var_0 + var_1 * var_1 + var_2 * var_2;
  }
  
  public double distanceToSqr(Entity param_0) {
    return distanceToSqr(param_0.position());
  }
  
  public double distanceToSqr(Vec3 param_0) {
    double var_0 = getX() - param_0.x;
    double var_1 = getY() - param_0.y;
    double var_2 = getZ() - param_0.z;
    return var_0 * var_0 + var_1 * var_1 + var_2 * var_2;
  }
  
  public void playerTouch(Player param_0) {}
  
  public void push(Entity param_0) {
    if (isPassengerOfSameVehicle(param_0))
      return; 
    if (param_0.noPhysics || this.noPhysics)
      return; 
    double var_0 = param_0.getX() - getX();
    double var_1 = param_0.getZ() - getZ();
    double var_2 = Mth.absMax(var_0, var_1);
    if (var_2 >= 0.009999999776482582D) {
      var_2 = Math.sqrt(var_2);
      var_0 /= var_2;
      var_1 /= var_2;
      double var_3 = 1.0D / var_2;
      if (var_3 > 1.0D)
        var_3 = 1.0D; 
      var_0 *= var_3;
      var_1 *= var_3;
      var_0 *= 0.05000000074505806D;
      var_1 *= 0.05000000074505806D;
      if (!isVehicle())
        push(-var_0, 0.0D, -var_1); 
      if (!param_0.isVehicle())
        param_0.push(var_0, 0.0D, var_1); 
    } 
  }
  
  public void push(double param_0, double param_1, double param_2) {
    setDeltaMovement(getDeltaMovement().add(param_0, param_1, param_2));
    this.hasImpulse = true;
  }
  
  protected void markHurt() {
    this.hurtMarked = true;
  }
  
  public boolean hurt(DamageSource param_0, float param_1) {
    if (isInvulnerableTo(param_0))
      return false; 
    markHurt();
    return false;
  }
  
  public final Vec3 getViewVector(float param_0) {
    return calculateViewVector(getViewXRot(param_0), getViewYRot(param_0));
  }
  
  public float getViewXRot(float param_0) {
    if (param_0 == 1.0F)
      return getXRot(); 
    return Mth.lerp(param_0, this.xRotO, getXRot());
  }
  
  public float getViewYRot(float param_0) {
    if (param_0 == 1.0F)
      return getYRot(); 
    return Mth.lerp(param_0, this.yRotO, getYRot());
  }
  
  protected final Vec3 calculateViewVector(float param_0, float param_1) {
    float var_0 = param_0 * 0.017453292F;
    float var_1 = -param_1 * 0.017453292F;
    float var_2 = Mth.cos(var_1);
    float var_3 = Mth.sin(var_1);
    float var_4 = Mth.cos(var_0);
    float var_5 = Mth.sin(var_0);
    return new Vec3((var_3 * var_4), -var_5, (var_2 * var_4));
  }
  
  public final Vec3 getUpVector(float param_0) {
    return calculateUpVector(getViewXRot(param_0), getViewYRot(param_0));
  }
  
  protected final Vec3 calculateUpVector(float param_0, float param_1) {
    return calculateViewVector(param_0 - 90.0F, param_1);
  }
  
  public final Vec3 getEyePosition() {
    return new Vec3(getX(), getEyeY(), getZ());
  }
  
  public final Vec3 getEyePosition(float param_0) {
    double var_0 = Mth.lerp(param_0, this.xo, getX());
    double var_1 = Mth.lerp(param_0, this.yo, getY()) + getEyeHeight();
    double var_2 = Mth.lerp(param_0, this.zo, getZ());
    return new Vec3(var_0, var_1, var_2);
  }
  
  public Vec3 getLightProbePosition(float param_0) {
    return getEyePosition(param_0);
  }
  
  public final Vec3 getPosition(float param_0) {
    double var_0 = Mth.lerp(param_0, this.xo, getX());
    double var_1 = Mth.lerp(param_0, this.yo, getY());
    double var_2 = Mth.lerp(param_0, this.zo, getZ());
    return new Vec3(var_0, var_1, var_2);
  }
  
  public HitResult pick(double param_0, float param_1, boolean param_2) {
    Vec3 var_0 = getEyePosition(param_1);
    Vec3 var_1 = getViewVector(param_1);
    Vec3 var_2 = var_0.add(var_1.x * param_0, var_1.y * param_0, var_1.z * param_0);
    return (HitResult)this.level.clip(new ClipContext(var_0, var_2, ClipContext.Block.OUTLINE, param_2 ? ClipContext.Fluid.ANY : ClipContext.Fluid.NONE, this));
  }
  
  public boolean isPickable() {
    return false;
  }
  
  public boolean isPushable() {
    return false;
  }
  
  public void awardKillScore(Entity param_0, int param_1, DamageSource param_2) {
    if (param_0 instanceof ServerPlayer)
      CriteriaTriggers.ENTITY_KILLED_PLAYER.trigger((ServerPlayer)param_0, this, param_2); 
  }
  
  public boolean shouldRender(double param_0, double param_1, double param_2) {
    double var_0 = getX() - param_0;
    double var_1 = getY() - param_1;
    double var_2 = getZ() - param_2;
    double var_3 = var_0 * var_0 + var_1 * var_1 + var_2 * var_2;
    return shouldRenderAtSqrDistance(var_3);
  }
  
  public boolean shouldRenderAtSqrDistance(double param_0) {
    double var_0 = getBoundingBox().getSize();
    if (Double.isNaN(var_0))
      var_0 = 1.0D; 
    var_0 *= 64.0D * viewScale;
    return (param_0 < var_0 * var_0);
  }
  
  public boolean saveAsPassenger(CompoundTag param_0) {
    if (this.removalReason != null && !this.removalReason.shouldSave())
      return false; 
    String var_0 = getEncodeId();
    if (var_0 == null)
      return false; 
    param_0.putString("id", var_0);
    saveWithoutId(param_0);
    return true;
  }
  
  public boolean save(CompoundTag param_0) {
    if (isPassenger())
      return false; 
    return saveAsPassenger(param_0);
  }
  
  public CompoundTag saveWithoutId(CompoundTag param_0) {
    try {
      if (this.vehicle != null) {
        param_0.put("Pos", (Tag)newDoubleList(new double[] { this.vehicle.getX(), getY(), this.vehicle.getZ() }));
      } else {
        param_0.put("Pos", (Tag)newDoubleList(new double[] { getX(), getY(), getZ() }));
      } 
      Vec3 var_0 = getDeltaMovement();
      param_0.put("Motion", (Tag)newDoubleList(new double[] { var_0.x, var_0.y, var_0.z }));
      param_0.put("Rotation", (Tag)newFloatList(new float[] { getYRot(), getXRot() }));
      param_0.putFloat("FallDistance", this.fallDistance);
      param_0.putShort("Fire", (short)this.remainingFireTicks);
      param_0.putShort("Air", (short)getAirSupply());
      param_0.putBoolean("OnGround", this.onGround);
      param_0.putBoolean("Invulnerable", this.invulnerable);
      param_0.putInt("PortalCooldown", this.portalCooldown);
      param_0.putUUID("UUID", getUUID());
      Component var_1 = getCustomName();
      if (var_1 != null)
        param_0.putString("CustomName", Component.Serializer.toJson(var_1)); 
      if (isCustomNameVisible())
        param_0.putBoolean("CustomNameVisible", isCustomNameVisible()); 
      if (isSilent())
        param_0.putBoolean("Silent", isSilent()); 
      if (isNoGravity())
        param_0.putBoolean("NoGravity", isNoGravity()); 
      if (this.hasGlowingTag)
        param_0.putBoolean("Glowing", true); 
      int var_2 = getTicksFrozen();
      if (var_2 > 0)
        param_0.putInt("TicksFrozen", getTicksFrozen()); 
      if (this.hasVisualFire)
        param_0.putBoolean("HasVisualFire", this.hasVisualFire); 
      if (!this.tags.isEmpty()) {
        ListTag var_3 = new ListTag();
        for (String var_4 : this.tags)
          var_3.add(StringTag.valueOf(var_4)); 
        param_0.put("Tags", (Tag)var_3);
      } 
      addAdditionalSaveData(param_0);
      if (isVehicle()) {
        ListTag var_5 = new ListTag();
        for (Entity var_6 : getPassengers()) {
          CompoundTag var_7 = new CompoundTag();
          if (var_6.saveAsPassenger(var_7))
            var_5.add(var_7); 
        } 
        if (!var_5.isEmpty())
          param_0.put("Passengers", (Tag)var_5); 
      } 
    } catch (Throwable var_8) {
      CrashReport var_9 = CrashReport.forThrowable(var_8, "Saving entity NBT");
      CrashReportCategory var_10 = var_9.addCategory("Entity being saved");
      fillCrashReportCategory(var_10);
      throw new ReportedException(var_9);
    } 
    return param_0;
  }
  
  public void load(CompoundTag param_0) {
    try {
      ListTag var_0 = param_0.getList("Pos", 6);
      ListTag var_1 = param_0.getList("Motion", 6);
      ListTag var_2 = param_0.getList("Rotation", 5);
      double var_3 = var_1.getDouble(0);
      double var_4 = var_1.getDouble(1);
      double var_5 = var_1.getDouble(2);
      setDeltaMovement(
          (Math.abs(var_3) > 10.0D) ? 0.0D : var_3, 
          (Math.abs(var_4) > 10.0D) ? 0.0D : var_4, 
          (Math.abs(var_5) > 10.0D) ? 0.0D : var_5);
      setPosRaw(var_0.getDouble(0), Mth.clamp(var_0.getDouble(1), -2.0E7D, 2.0E7D), var_0.getDouble(2));
      setYRot(var_2.getFloat(0));
      setXRot(var_2.getFloat(1));
      setOldPosAndRot();
      setYHeadRot(getYRot());
      setYBodyRot(getYRot());
      this.fallDistance = param_0.getFloat("FallDistance");
      this.remainingFireTicks = param_0.getShort("Fire");
      if (param_0.contains("Air"))
        setAirSupply(param_0.getShort("Air")); 
      this.onGround = param_0.getBoolean("OnGround");
      this.invulnerable = param_0.getBoolean("Invulnerable");
      this.portalCooldown = param_0.getInt("PortalCooldown");
      if (param_0.hasUUID("UUID")) {
        this.uuid = param_0.getUUID("UUID");
        this.stringUUID = this.uuid.toString();
      } 
      if (!Double.isFinite(getX()) || !Double.isFinite(getY()) || !Double.isFinite(getZ()))
        throw new IllegalStateException("Entity has invalid position"); 
      if (!Double.isFinite(getYRot()) || !Double.isFinite(getXRot()))
        throw new IllegalStateException("Entity has invalid rotation"); 
      reapplyPosition();
      setRot(getYRot(), getXRot());
      if (param_0.contains("CustomName", 8)) {
        String var_6 = param_0.getString("CustomName");
        try {
          setCustomName((Component)Component.Serializer.fromJson(var_6));
        } catch (Exception var_7) {
          LOGGER.warn("Failed to parse entity custom name {}", var_6, var_7);
        } 
      } 
      setCustomNameVisible(param_0.getBoolean("CustomNameVisible"));
      setSilent(param_0.getBoolean("Silent"));
      setNoGravity(param_0.getBoolean("NoGravity"));
      setGlowingTag(param_0.getBoolean("Glowing"));
      setTicksFrozen(param_0.getInt("TicksFrozen"));
      this.hasVisualFire = param_0.getBoolean("HasVisualFire");
      if (param_0.contains("Tags", 9)) {
        this.tags.clear();
        ListTag var_8 = param_0.getList("Tags", 8);
        int var_9 = Math.min(var_8.size(), 1024);
        for (int var_10 = 0; var_10 < var_9; var_10++)
          this.tags.add(var_8.getString(var_10)); 
      } 
      readAdditionalSaveData(param_0);
      if (repositionEntityAfterLoad())
        reapplyPosition(); 
    } catch (Throwable var_11) {
      CrashReport var_12 = CrashReport.forThrowable(var_11, "Loading entity NBT");
      CrashReportCategory var_13 = var_12.addCategory("Entity being loaded");
      fillCrashReportCategory(var_13);
      throw new ReportedException(var_12);
    } 
  }
  
  protected boolean repositionEntityAfterLoad() {
    return true;
  }
  
  @Nullable
  protected final String getEncodeId() {
    EntityType<?> var_0 = getType();
    ResourceLocation var_1 = EntityType.getKey(var_0);
    return (!var_0.canSerialize() || var_1 == null) ? null : var_1.toString();
  }
  
  protected ListTag newDoubleList(double... param_0) {
    ListTag var_0 = new ListTag();
    for (double var_1 : param_0)
      var_0.add(DoubleTag.valueOf(var_1)); 
    return var_0;
  }
  
  protected ListTag newFloatList(float... param_0) {
    ListTag var_0 = new ListTag();
    for (float var_1 : param_0)
      var_0.add(FloatTag.valueOf(var_1)); 
    return var_0;
  }
  
  @Nullable
  public ItemEntity spawnAtLocation(ItemLike param_0) {
    return spawnAtLocation(param_0, 0);
  }
  
  @Nullable
  public ItemEntity spawnAtLocation(ItemLike param_0, int param_1) {
    return spawnAtLocation(new ItemStack(param_0), param_1);
  }
  
  @Nullable
  public ItemEntity spawnAtLocation(ItemStack param_0) {
    return spawnAtLocation(param_0, 0.0F);
  }
  
  @Nullable
  public ItemEntity spawnAtLocation(ItemStack param_0, float param_1) {
    if (param_0.isEmpty())
      return null; 
    if (this.level.isClientSide)
      return null; 
    ItemEntity var_0 = new ItemEntity(this.level, getX(), getY() + param_1, getZ(), param_0);
    var_0.setDefaultPickUpDelay();
    this.level.addFreshEntity((Entity)var_0);
    return var_0;
  }
  
  public boolean isAlive() {
    return !isRemoved();
  }
  
  public boolean isInWall() {
    if (this.noPhysics)
      return false; 
    float var_0 = this.dimensions.width * 0.8F;
    AABB var_1 = AABB.ofSize(getEyePosition(), var_0, 1.0E-6D, var_0);
    return this.level.getBlockCollisions(this, var_1, (param_0, param_1) -> param_0.isSuffocating((BlockGetter)this.level, param_1)).findAny().isPresent();
  }
  
  public InteractionResult interact(Player param_0, InteractionHand param_1) {
    return InteractionResult.PASS;
  }
  
  public boolean canCollideWith(Entity param_0) {
    return (param_0.canBeCollidedWith() && !isPassengerOfSameVehicle(param_0));
  }
  
  public boolean canBeCollidedWith() {
    return false;
  }
  
  public void rideTick() {
    setDeltaMovement(Vec3.ZERO);
    tick();
    if (!isPassenger())
      return; 
    getVehicle().positionRider(this);
  }
  
  public void positionRider(Entity param_0) {
    positionRider(param_0, Entity::setPos);
  }
  
  private void positionRider(Entity param_0, MoveFunction param_1) {
    if (!hasPassenger(param_0))
      return; 
    double var_0 = getY() + getPassengersRidingOffset() + param_0.getMyRidingOffset();
    param_1.accept(param_0, getX(), var_0, getZ());
  }
  
  public void onPassengerTurned(Entity param_0) {}
  
  public double getMyRidingOffset() {
    return 0.0D;
  }
  
  public double getPassengersRidingOffset() {
    return this.dimensions.height * 0.75D;
  }
  
  public boolean startRiding(Entity param_0) {
    return startRiding(param_0, false);
  }
  
  public boolean showVehicleHealth() {
    return this instanceof LivingEntity;
  }
  
  public boolean startRiding(Entity param_0, boolean param_1) {
    if (param_0 == this.vehicle)
      return false; 
    Entity var_0 = param_0;
    while (var_0.vehicle != null) {
      if (var_0.vehicle == this)
        return false; 
      var_0 = var_0.vehicle;
    } 
    if (!param_1 && (!canRide(param_0) || !param_0.canAddPassenger(this)))
      return false; 
    if (isPassenger())
      stopRiding(); 
    setPose(Pose.STANDING);
    this.vehicle = param_0;
    this.vehicle.addPassenger(this);
    param_0.getIndirectPassengersStream()
      .filter(param_0 -> param_0 instanceof ServerPlayer)
      .forEach(param_0 -> CriteriaTriggers.START_RIDING_TRIGGER.trigger((ServerPlayer)param_0));
    return true;
  }
  
  protected boolean canRide(Entity param_0) {
    return (!isShiftKeyDown() && this.boardingCooldown <= 0);
  }
  
  protected boolean canEnterPose(Pose param_0) {
    return this.level.noCollision(this, getBoundingBoxForPose(param_0).deflate(1.0E-7D));
  }
  
  public void ejectPassengers() {
    for (int var_0 = this.passengers.size() - 1; var_0 >= 0; var_0--)
      ((Entity)this.passengers.get(var_0)).stopRiding(); 
  }
  
  public void removeVehicle() {
    if (this.vehicle != null) {
      Entity var_0 = this.vehicle;
      this.vehicle = null;
      var_0.removePassenger(this);
    } 
  }
  
  public void stopRiding() {
    removeVehicle();
  }
  
  protected void addPassenger(Entity param_0) {
    if (param_0.getVehicle() != this)
      throw new IllegalStateException("Use x.startRiding(y), not y.addPassenger(x)"); 
    if (this.passengers.isEmpty()) {
      this.passengers = ImmutableList.of(param_0);
    } else {
      List<Entity> var_0 = Lists.newArrayList((Iterable)this.passengers);
      if (!this.level.isClientSide && param_0 instanceof Player && !(getControllingPassenger() instanceof Player)) {
        var_0.add(0, param_0);
      } else {
        var_0.add(param_0);
      } 
      this.passengers = ImmutableList.copyOf(var_0);
    } 
  }
  
  protected void removePassenger(Entity param_0) {
    if (param_0.getVehicle() == this)
      throw new IllegalStateException("Use x.stopRiding(y), not y.removePassenger(x)"); 
    if (this.passengers.size() == 1 && this.passengers.get(0) == param_0) {
      this.passengers = ImmutableList.of();
    } else {
      this.passengers = (ImmutableList<Entity>)this.passengers.stream().filter(param_1 -> (param_1 != param_0)).collect(ImmutableList.toImmutableList());
    } 
    param_0.boardingCooldown = 60;
  }
  
  protected boolean canAddPassenger(Entity param_0) {
    return this.passengers.isEmpty();
  }
  
  public void lerpTo(double param_0, double param_1, double param_2, float param_3, float param_4, int param_5, boolean param_6) {
    setPos(param_0, param_1, param_2);
    setRot(param_3, param_4);
  }
  
  public void lerpHeadTo(float param_0, int param_1) {
    setYHeadRot(param_0);
  }
  
  public float getPickRadius() {
    return 0.0F;
  }
  
  public Vec3 getLookAngle() {
    return calculateViewVector(getXRot(), getYRot());
  }
  
  public Vec2 getRotationVector() {
    return new Vec2(getXRot(), getYRot());
  }
  
  public Vec3 getForward() {
    return Vec3.directionFromRotation(getRotationVector());
  }
  
  public void handleInsidePortal(BlockPos param_0) {
    if (isOnPortalCooldown()) {
      setPortalCooldown();
      return;
    } 
    if (!this.level.isClientSide && !param_0.equals(this.portalEntrancePos))
      this.portalEntrancePos = param_0.immutable(); 
    this.isInsidePortal = true;
  }
  
  protected void handleNetherPortal() {
    if (!(this.level instanceof ServerLevel))
      return; 
    int var_0 = getPortalWaitTime();
    ServerLevel var_1 = (ServerLevel)this.level;
    if (this.isInsidePortal) {
      MinecraftServer var_2 = var_1.getServer();
      ResourceKey<Level> var_3 = (this.level.dimension() == Level.NETHER) ? Level.OVERWORLD : Level.NETHER;
      ServerLevel var_4 = var_2.getLevel(var_3);
      if (var_4 != null && var_2.isNetherEnabled() && !isPassenger() && this.portalTime++ >= var_0) {
        this.level.getProfiler().push("portal");
        this.portalTime = var_0;
        setPortalCooldown();
        changeDimension(var_4);
        this.level.getProfiler().pop();
      } 
      this.isInsidePortal = false;
    } else {
      if (this.portalTime > 0)
        this.portalTime -= 4; 
      if (this.portalTime < 0)
        this.portalTime = 0; 
    } 
    processPortalCooldown();
  }
  
  public int getDimensionChangingDelay() {
    return 300;
  }
  
  public void lerpMotion(double param_0, double param_1, double param_2) {
    setDeltaMovement(param_0, param_1, param_2);
  }
  
  public void handleEntityEvent(byte param_0) {
    switch (param_0) {
      case 53:
        HoneyBlock.showSlideParticles(this);
        break;
    } 
  }
  
  public void animateHurt() {}
  
  public Iterable<ItemStack> getHandSlots() {
    return EMPTY_LIST;
  }
  
  public Iterable<ItemStack> getArmorSlots() {
    return EMPTY_LIST;
  }
  
  public Iterable<ItemStack> getAllSlots() {
    return Iterables.concat(getHandSlots(), getArmorSlots());
  }
  
  public void setItemSlot(EquipmentSlot param_0, ItemStack param_1) {}
  
  public boolean isOnFire() {
    boolean var_0 = (this.level != null && this.level.isClientSide);
    return (!fireImmune() && (this.remainingFireTicks > 0 || (var_0 && getSharedFlag(0))));
  }
  
  public boolean isPassenger() {
    return (getVehicle() != null);
  }
  
  public boolean isVehicle() {
    return !this.passengers.isEmpty();
  }
  
  public boolean rideableUnderWater() {
    return true;
  }
  
  public void setShiftKeyDown(boolean param_0) {
    setSharedFlag(1, param_0);
  }
  
  public boolean isShiftKeyDown() {
    return getSharedFlag(1);
  }
  
  public boolean isSteppingCarefully() {
    return isShiftKeyDown();
  }
  
  public boolean isSuppressingBounce() {
    return isShiftKeyDown();
  }
  
  public boolean isDiscrete() {
    return isShiftKeyDown();
  }
  
  public boolean isDescending() {
    return isShiftKeyDown();
  }
  
  public boolean isCrouching() {
    return (getPose() == Pose.CROUCHING);
  }
  
  public boolean isSprinting() {
    return getSharedFlag(3);
  }
  
  public void setSprinting(boolean param_0) {
    setSharedFlag(3, param_0);
  }
  
  public boolean isSwimming() {
    return getSharedFlag(4);
  }
  
  public boolean isVisuallySwimming() {
    return (getPose() == Pose.SWIMMING);
  }
  
  public boolean isVisuallyCrawling() {
    return (isVisuallySwimming() && !isInWater());
  }
  
  public void setSwimming(boolean param_0) {
    setSharedFlag(4, param_0);
  }
  
  public final boolean hasGlowingTag() {
    return this.hasGlowingTag;
  }
  
  public final void setGlowingTag(boolean param_0) {
    this.hasGlowingTag = param_0;
    setSharedFlag(6, isCurrentlyGlowing());
  }
  
  public boolean isCurrentlyGlowing() {
    if (this.level.isClientSide())
      return getSharedFlag(6); 
    return this.hasGlowingTag;
  }
  
  public boolean isInvisible() {
    return getSharedFlag(5);
  }
  
  public boolean isInvisibleTo(Player param_0) {
    if (param_0.isSpectator())
      return false; 
    Team var_0 = getTeam();
    if (var_0 != null && param_0 != null && param_0.getTeam() == var_0 && var_0.canSeeFriendlyInvisibles())
      return false; 
    return isInvisible();
  }
  
  @Nullable
  public GameEventListenerRegistrar getGameEventListenerRegistrar() {
    return null;
  }
  
  @Nullable
  public Team getTeam() {
    return (Team)this.level.getScoreboard().getPlayersTeam(getScoreboardName());
  }
  
  public boolean isAlliedTo(Entity param_0) {
    return isAlliedTo(param_0.getTeam());
  }
  
  public boolean isAlliedTo(Team param_0) {
    if (getTeam() != null)
      return getTeam().isAlliedTo(param_0); 
    return false;
  }
  
  public void setInvisible(boolean param_0) {
    setSharedFlag(5, param_0);
  }
  
  protected boolean getSharedFlag(int param_0) {
    return ((((Byte)this.entityData.get(DATA_SHARED_FLAGS_ID)).byteValue() & 1 << param_0) != 0);
  }
  
  protected void setSharedFlag(int param_0, boolean param_1) {
    byte var_0 = ((Byte)this.entityData.get(DATA_SHARED_FLAGS_ID)).byteValue();
    if (param_1) {
      this.entityData.set(DATA_SHARED_FLAGS_ID, Byte.valueOf((byte)(var_0 | 1 << param_0)));
    } else {
      this.entityData.set(DATA_SHARED_FLAGS_ID, Byte.valueOf((byte)(var_0 & (1 << param_0 ^ 0xFFFFFFFF))));
    } 
  }
  
  public int getMaxAirSupply() {
    return 300;
  }
  
  public int getAirSupply() {
    return ((Integer)this.entityData.get(DATA_AIR_SUPPLY_ID)).intValue();
  }
  
  public void setAirSupply(int param_0) {
    this.entityData.set(DATA_AIR_SUPPLY_ID, Integer.valueOf(param_0));
  }
  
  public int getTicksFrozen() {
    return ((Integer)this.entityData.get(DATA_TICKS_FROZEN)).intValue();
  }
  
  public void setTicksFrozen(int param_0) {
    this.entityData.set(DATA_TICKS_FROZEN, Integer.valueOf(param_0));
  }
  
  public float getPercentFrozen() {
    int var_0 = getTicksRequiredToFreeze();
    return Math.min(getTicksFrozen(), var_0) / var_0;
  }
  
  public boolean isFullyFrozen() {
    return (getTicksFrozen() >= getTicksRequiredToFreeze());
  }
  
  public int getTicksRequiredToFreeze() {
    return 140;
  }
  
  public void thunderHit(ServerLevel param_0, LightningBolt param_1) {
    setRemainingFireTicks(this.remainingFireTicks + 1);
    if (this.remainingFireTicks == 0)
      setSecondsOnFire(8); 
    hurt(DamageSource.LIGHTNING_BOLT, 5.0F);
  }
  
  public void onAboveBubbleCol(boolean param_0) {
    double var_2;
    Vec3 var_0 = getDeltaMovement();
    if (param_0) {
      double var_1 = Math.max(-0.9D, var_0.y - 0.03D);
    } else {
      var_2 = Math.min(1.8D, var_0.y + 0.1D);
    } 
    setDeltaMovement(var_0.x, var_2, var_0.z);
  }
  
  public void onInsideBubbleColumn(boolean param_0) {
    double var_2;
    Vec3 var_0 = getDeltaMovement();
    if (param_0) {
      double var_1 = Math.max(-0.3D, var_0.y - 0.03D);
    } else {
      var_2 = Math.min(0.7D, var_0.y + 0.06D);
    } 
    setDeltaMovement(var_0.x, var_2, var_0.z);
    this.fallDistance = 0.0F;
  }
  
  public void killed(ServerLevel param_0, LivingEntity param_1) {}
  
  protected void moveTowardsClosestSpace(double param_0, double param_1, double param_2) {
    BlockPos var_0 = new BlockPos(param_0, param_1, param_2);
    Vec3 var_1 = new Vec3(param_0 - var_0.getX(), param_1 - var_0.getY(), param_2 - var_0.getZ());
    BlockPos.MutableBlockPos var_2 = new BlockPos.MutableBlockPos();
    Direction var_3 = Direction.UP;
    double var_4 = Double.MAX_VALUE;
    for (Direction var_5 : new Direction[] { Direction.NORTH, Direction.SOUTH, Direction.WEST, Direction.EAST, Direction.UP }) {
      var_2.setWithOffset((Vec3i)var_0, var_5);
      if (!this.level.getBlockState((BlockPos)var_2).isCollisionShapeFullBlock((BlockGetter)this.level, (BlockPos)var_2)) {
        double var_6 = var_1.get(var_5.getAxis());
        double var_7 = (var_5.getAxisDirection() == Direction.AxisDirection.POSITIVE) ? (1.0D - var_6) : var_6;
        if (var_7 < var_4) {
          var_4 = var_7;
          var_3 = var_5;
        } 
      } 
    } 
    float var_8 = this.random.nextFloat() * 0.2F + 0.1F;
    float var_9 = var_3.getAxisDirection().getStep();
    Vec3 var_10 = getDeltaMovement().scale(0.75D);
    if (var_3.getAxis() == Direction.Axis.X) {
      setDeltaMovement((var_9 * var_8), var_10.y, var_10.z);
    } else if (var_3.getAxis() == Direction.Axis.Y) {
      setDeltaMovement(var_10.x, (var_9 * var_8), var_10.z);
    } else if (var_3.getAxis() == Direction.Axis.Z) {
      setDeltaMovement(var_10.x, var_10.y, (var_9 * var_8));
    } 
  }
  
  public void makeStuckInBlock(BlockState param_0, Vec3 param_1) {
    this.fallDistance = 0.0F;
    this.stuckSpeedMultiplier = param_1;
  }
  
  private static Component removeAction(Component param_0) {
    MutableComponent var_0 = param_0.plainCopy().setStyle(param_0.getStyle().withClickEvent(null));
    for (Component var_1 : param_0.getSiblings())
      var_0.append(removeAction(var_1)); 
    return (Component)var_0;
  }
  
  public Component getName() {
    Component var_0 = getCustomName();
    if (var_0 != null)
      return removeAction(var_0); 
    return getTypeName();
  }
  
  protected Component getTypeName() {
    return this.type.getDescription();
  }
  
  public boolean is(Entity param_0) {
    return (this == param_0);
  }
  
  public float getYHeadRot() {
    return 0.0F;
  }
  
  public void setYHeadRot(float param_0) {}
  
  public void setYBodyRot(float param_0) {}
  
  public boolean isAttackable() {
    return true;
  }
  
  public boolean skipAttackInteraction(Entity param_0) {
    return false;
  }
  
  public String toString() {
    return String.format(Locale.ROOT, "%s['%s'/%d, l='%s', x=%.2f, y=%.2f, z=%.2f]", new Object[] { getClass().getSimpleName(), getName().getString(), Integer.valueOf(this.id), (this.level == null) ? "~NULL~" : this.level.toString(), Double.valueOf(getX()), Double.valueOf(getY()), Double.valueOf(getZ()) });
  }
  
  public boolean isInvulnerableTo(DamageSource param_0) {
    return (isRemoved() || (this.invulnerable && param_0 != DamageSource.OUT_OF_WORLD && !param_0.isCreativePlayer()));
  }
  
  public boolean isInvulnerable() {
    return this.invulnerable;
  }
  
  public void setInvulnerable(boolean param_0) {
    this.invulnerable = param_0;
  }
  
  public void copyPosition(Entity param_0) {
    moveTo(param_0.getX(), param_0.getY(), param_0.getZ(), param_0.getYRot(), param_0.getXRot());
  }
  
  public void restoreFrom(Entity param_0) {
    CompoundTag var_0 = param_0.saveWithoutId(new CompoundTag());
    var_0.remove("Dimension");
    load(var_0);
    this.portalCooldown = param_0.portalCooldown;
    this.portalEntrancePos = param_0.portalEntrancePos;
  }
  
  @Nullable
  public Entity changeDimension(ServerLevel param_0) {
    if (!(this.level instanceof ServerLevel) || isRemoved())
      return null; 
    this.level.getProfiler().push("changeDimension");
    unRide();
    this.level.getProfiler().push("reposition");
    PortalInfo var_0 = findDimensionEntryPoint(param_0);
    if (var_0 == null)
      return null; 
    this.level.getProfiler().popPush("reloading");
    Entity var_1 = (Entity)getType().create((Level)param_0);
    if (var_1 != null) {
      var_1.restoreFrom(this);
      var_1.moveTo(var_0.pos.x, var_0.pos.y, var_0.pos.z, var_0.yRot, var_1.getXRot());
      var_1.setDeltaMovement(var_0.speed);
      param_0.addDuringTeleport(var_1);
      if (param_0.dimension() == Level.END)
        ServerLevel.makeObsidianPlatform(param_0); 
    } 
    removeAfterChangingDimensions();
    this.level.getProfiler().pop();
    ((ServerLevel)this.level).resetEmptyTime();
    param_0.resetEmptyTime();
    this.level.getProfiler().pop();
    return var_1;
  }
  
  protected void removeAfterChangingDimensions() {
    setRemoved(RemovalReason.CHANGED_DIMENSION);
  }
  
  @Nullable
  protected PortalInfo findDimensionEntryPoint(ServerLevel param_0) {
    boolean var_0 = (this.level.dimension() == Level.END && param_0.dimension() == Level.OVERWORLD);
    boolean var_1 = (param_0.dimension() == Level.END);
    if (var_0 || var_1) {
      BlockPos var_3;
      if (var_1) {
        BlockPos var_2 = ServerLevel.END_SPAWN_POINT;
      } else {
        var_3 = param_0.getHeightmapPos(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, param_0.getSharedSpawnPos());
      } 
      return new PortalInfo(new Vec3(var_3
            .getX() + 0.5D, var_3.getY(), var_3.getZ() + 0.5D), 
          getDeltaMovement(), 
          getYRot(), 
          getXRot());
    } 
    boolean var_4 = (param_0.dimension() == Level.NETHER);
    if (this.level.dimension() != Level.NETHER && !var_4)
      return null; 
    WorldBorder var_5 = param_0.getWorldBorder();
    double var_6 = Math.max(-2.9999872E7D, var_5.getMinX() + 16.0D);
    double var_7 = Math.max(-2.9999872E7D, var_5.getMinZ() + 16.0D);
    double var_8 = Math.min(2.9999872E7D, var_5.getMaxX() - 16.0D);
    double var_9 = Math.min(2.9999872E7D, var_5.getMaxZ() - 16.0D);
    double var_10 = DimensionType.getTeleportationScale(this.level.dimensionType(), param_0.dimensionType());
    BlockPos var_11 = new BlockPos(Mth.clamp(getX() * var_10, var_6, var_8), getY(), Mth.clamp(getZ() * var_10, var_7, var_9));
    return getExitPortal(param_0, var_11, var_4)
      .<PortalInfo>map(param_1 -> {
          Direction.Axis var_4;
          Vec3 var_5;
          BlockState var_0 = this.level.getBlockState(this.portalEntrancePos);
          if (var_0.hasProperty((Property)BlockStateProperties.HORIZONTAL_AXIS)) {
            Direction.Axis var_1 = (Direction.Axis)var_0.getValue((Property)BlockStateProperties.HORIZONTAL_AXIS);
            BlockUtil.FoundRectangle var_2 = BlockUtil.getLargestRectangleAround(this.portalEntrancePos, var_1, 21, Direction.Axis.Y, 21, ());
            Vec3 var_3 = getRelativePortalPosition(var_1, var_2);
          } else {
            var_4 = Direction.Axis.X;
            var_5 = new Vec3(0.5D, 0.0D, 0.0D);
          } 
          return PortalShape.createPortalInfo(param_0, param_1, var_4, var_5, getDimensions(getPose()), getDeltaMovement(), getYRot(), getXRot());
        }).orElse(null);
  }
  
  protected Vec3 getRelativePortalPosition(Direction.Axis param_0, BlockUtil.FoundRectangle param_1) {
    return PortalShape.getRelativePosition(param_1, param_0, position(), getDimensions(getPose()));
  }
  
  protected Optional<BlockUtil.FoundRectangle> getExitPortal(ServerLevel param_0, BlockPos param_1, boolean param_2) {
    return param_0.getPortalForcer().findPortalAround(param_1, param_2);
  }
  
  public boolean canChangeDimensions() {
    return true;
  }
  
  public float getBlockExplosionResistance(Explosion param_0, BlockGetter param_1, BlockPos param_2, BlockState param_3, FluidState param_4, float param_5) {
    return param_5;
  }
  
  public boolean shouldBlockExplode(Explosion param_0, BlockGetter param_1, BlockPos param_2, BlockState param_3, float param_4) {
    return true;
  }
  
  public int getMaxFallDistance() {
    return 3;
  }
  
  public boolean isIgnoringBlockTriggers() {
    return false;
  }
  
  public void fillCrashReportCategory(CrashReportCategory param_0) {
    param_0.setDetail("Entity Type", () -> "" + EntityType.getKey(getType()) + " (" + EntityType.getKey(getType()) + ")");
    param_0.setDetail("Entity ID", Integer.valueOf(this.id));
    param_0.setDetail("Entity Name", () -> getName().getString());
    param_0.setDetail("Entity's Exact location", String.format(Locale.ROOT, "%.2f, %.2f, %.2f", new Object[] { Double.valueOf(getX()), Double.valueOf(getY()), Double.valueOf(getZ()) }));
    param_0.setDetail("Entity's Block location", CrashReportCategory.formatLocation((LevelHeightAccessor)this.level, Mth.floor(getX()), Mth.floor(getY()), Mth.floor(getZ())));
    Vec3 var_0 = getDeltaMovement();
    param_0.setDetail("Entity's Momentum", String.format(Locale.ROOT, "%.2f, %.2f, %.2f", new Object[] { Double.valueOf(var_0.x), Double.valueOf(var_0.y), Double.valueOf(var_0.z) }));
    param_0.setDetail("Entity's Passengers", () -> getPassengers().toString());
    param_0.setDetail("Entity's Vehicle", () -> String.valueOf(getVehicle()));
  }
  
  public boolean displayFireAnimation() {
    return (isOnFire() && !isSpectator());
  }
  
  public void setUUID(UUID param_0) {
    this.uuid = param_0;
    this.stringUUID = this.uuid.toString();
  }
  
  public UUID getUUID() {
    return this.uuid;
  }
  
  public String getStringUUID() {
    return this.stringUUID;
  }
  
  public String getScoreboardName() {
    return this.stringUUID;
  }
  
  public boolean isPushedByFluid() {
    return true;
  }
  
  public static double getViewScale() {
    return viewScale;
  }
  
  public static void setViewScale(double param_0) {
    viewScale = param_0;
  }
  
  public Component getDisplayName() {
    return (Component)PlayerTeam.formatNameForTeam(getTeam(), getName()).withStyle(param_0 -> param_0.withHoverEvent(createHoverEvent()).withInsertion(getStringUUID()));
  }
  
  public void setCustomName(@Nullable Component param_0) {
    this.entityData.set(DATA_CUSTOM_NAME, Optional.ofNullable(param_0));
  }
  
  @Nullable
  public Component getCustomName() {
    return ((Optional<Component>)this.entityData.get(DATA_CUSTOM_NAME)).orElse(null);
  }
  
  public boolean hasCustomName() {
    return ((Optional)this.entityData.get(DATA_CUSTOM_NAME)).isPresent();
  }
  
  public void setCustomNameVisible(boolean param_0) {
    this.entityData.set(DATA_CUSTOM_NAME_VISIBLE, Boolean.valueOf(param_0));
  }
  
  public boolean isCustomNameVisible() {
    return ((Boolean)this.entityData.get(DATA_CUSTOM_NAME_VISIBLE)).booleanValue();
  }
  
  public final void teleportToWithTicket(double param_0, double param_1, double param_2) {
    if (!(this.level instanceof ServerLevel))
      return; 
    ChunkPos var_0 = new ChunkPos(new BlockPos(param_0, param_1, param_2));
    ((ServerLevel)this.level).getChunkSource().addRegionTicket(TicketType.POST_TELEPORT, var_0, 0, Integer.valueOf(getId()));
    this.level.getChunk(var_0.x, var_0.z);
    teleportTo(param_0, param_1, param_2);
  }
  
  public void dismountTo(double param_0, double param_1, double param_2) {
    teleportTo(param_0, param_1, param_2);
  }
  
  public void teleportTo(double param_0, double param_1, double param_2) {
    if (!(this.level instanceof ServerLevel))
      return; 
    moveTo(param_0, param_1, param_2, getYRot(), getXRot());
    getSelfAndPassengers().forEach(param_0 -> {
          UnmodifiableIterator<Entity> unmodifiableIterator = param_0.passengers.iterator();
          while (unmodifiableIterator.hasNext()) {
            Entity var_0 = unmodifiableIterator.next();
            param_0.positionRider(var_0, Entity::moveTo);
          } 
        });
  }
  
  public boolean shouldShowName() {
    return isCustomNameVisible();
  }
  
  public void onSyncedDataUpdated(EntityDataAccessor<?> param_0) {
    if (DATA_POSE.equals(param_0))
      refreshDimensions(); 
  }
  
  public void refreshDimensions() {
    EntityDimensions var_0 = this.dimensions;
    Pose var_1 = getPose();
    EntityDimensions var_2 = getDimensions(var_1);
    this.dimensions = var_2;
    this.eyeHeight = getEyeHeight(var_1, var_2);
    reapplyPosition();
    boolean var_3 = (var_2.width <= 4.0D && var_2.height <= 4.0D);
    if (!this.level.isClientSide && !this.firstTick && !this.noPhysics && var_3 && (var_2.width > var_0.width || var_2.height > var_0.height) && !(this instanceof Player)) {
      Vec3 var_4 = position().add(0.0D, var_0.height / 2.0D, 0.0D);
      double var_5 = Math.max(0.0F, var_2.width - var_0.width) + 1.0E-6D;
      double var_6 = Math.max(0.0F, var_2.height - var_0.height) + 1.0E-6D;
      VoxelShape var_7 = Shapes.create(AABB.ofSize(var_4, var_5, var_6, var_5));
      this.level.findFreePosition(this, var_7, var_4, var_2.width, var_2.height, var_2.width).ifPresent(param_1 -> setPos(param_1.add(0.0D, -param_0.height / 2.0D, 0.0D)));
    } 
  }
  
  public Direction getDirection() {
    return Direction.fromYRot(getYRot());
  }
  
  public Direction getMotionDirection() {
    return getDirection();
  }
  
  protected HoverEvent createHoverEvent() {
    return new HoverEvent(HoverEvent.Action.SHOW_ENTITY, new HoverEvent.EntityTooltipInfo(getType(), getUUID(), getName()));
  }
  
  public boolean broadcastToPlayer(ServerPlayer param_0) {
    return true;
  }
  
  public final AABB getBoundingBox() {
    return this.bb;
  }
  
  public AABB getBoundingBoxForCulling() {
    return getBoundingBox();
  }
  
  protected AABB getBoundingBoxForPose(Pose param_0) {
    EntityDimensions var_0 = getDimensions(param_0);
    float var_1 = var_0.width / 2.0F;
    Vec3 var_2 = new Vec3(getX() - var_1, getY(), getZ() - var_1);
    Vec3 var_3 = new Vec3(getX() + var_1, getY() + var_0.height, getZ() + var_1);
    return new AABB(var_2, var_3);
  }
  
  public final void setBoundingBox(AABB param_0) {
    this.bb = param_0;
  }
  
  protected float getEyeHeight(Pose param_0, EntityDimensions param_1) {
    return param_1.height * 0.85F;
  }
  
  public float getEyeHeight(Pose param_0) {
    return getEyeHeight(param_0, getDimensions(param_0));
  }
  
  public final float getEyeHeight() {
    return this.eyeHeight;
  }
  
  public Vec3 getLeashOffset() {
    return new Vec3(0.0D, getEyeHeight(), (getBbWidth() * 0.4F));
  }
  
  public SlotAccess getSlot(int param_0) {
    return SlotAccess.NULL;
  }
  
  public void sendMessage(Component param_0, UUID param_1) {}
  
  public Level getCommandSenderWorld() {
    return this.level;
  }
  
  @Nullable
  public MinecraftServer getServer() {
    return this.level.getServer();
  }
  
  public InteractionResult interactAt(Player param_0, Vec3 param_1, InteractionHand param_2) {
    return InteractionResult.PASS;
  }
  
  public boolean ignoreExplosion() {
    return false;
  }
  
  public void doEnchantDamageEffects(LivingEntity param_0, Entity param_1) {
    if (param_1 instanceof LivingEntity)
      EnchantmentHelper.doPostHurtEffects((LivingEntity)param_1, param_0); 
    EnchantmentHelper.doPostDamageEffects(param_0, param_1);
  }
  
  public void startSeenByPlayer(ServerPlayer param_0) {}
  
  public void stopSeenByPlayer(ServerPlayer param_0) {}
  
  public float rotate(Rotation param_0) {
    float var_0 = Mth.wrapDegrees(getYRot());
    switch (param_0) {
      case LEFT_RIGHT:
        return var_0 + 180.0F;
      case FRONT_BACK:
        return var_0 + 270.0F;
      case null:
        return var_0 + 90.0F;
    } 
    return var_0;
  }
  
  public float mirror(Mirror param_0) {
    float var_0 = Mth.wrapDegrees(getYRot());
    switch (param_0) {
      case LEFT_RIGHT:
        return -var_0;
      case FRONT_BACK:
        return 180.0F - var_0;
    } 
    return var_0;
  }
  
  public boolean onlyOpCanSetNbt() {
    return false;
  }
  
  @Nullable
  public Entity getControllingPassenger() {
    return null;
  }
  
  public final List<Entity> getPassengers() {
    return (List<Entity>)this.passengers;
  }
  
  @Nullable
  public Entity getFirstPassenger() {
    return this.passengers.isEmpty() ? null : (Entity)this.passengers.get(0);
  }
  
  public boolean hasPassenger(Entity param_0) {
    return this.passengers.contains(param_0);
  }
  
  public boolean hasPassenger(Predicate<Entity> param_0) {
    for (UnmodifiableIterator<Entity> unmodifiableIterator = this.passengers.iterator(); unmodifiableIterator.hasNext(); ) {
      Entity var_0 = unmodifiableIterator.next();
      if (param_0.test(var_0))
        return true; 
    } 
    return false;
  }
  
  private Stream<Entity> getIndirectPassengersStream() {
    return this.passengers.stream().flatMap(Entity::getSelfAndPassengers);
  }
  
  public Stream<Entity> getSelfAndPassengers() {
    return Stream.concat(Stream.of(this), getIndirectPassengersStream());
  }
  
  public Stream<Entity> getPassengersAndSelf() {
    return Stream.concat(this.passengers.stream().flatMap(Entity::getPassengersAndSelf), Stream.of(this));
  }
  
  public Iterable<Entity> getIndirectPassengers() {
    return () -> getIndirectPassengersStream().iterator();
  }
  
  public boolean hasExactlyOnePlayerPassenger() {
    return (getIndirectPassengersStream().filter(param_0 -> param_0 instanceof Player).count() == 1L);
  }
  
  public Entity getRootVehicle() {
    Entity var_0 = this;
    while (var_0.isPassenger())
      var_0 = var_0.getVehicle(); 
    return var_0;
  }
  
  public boolean isPassengerOfSameVehicle(Entity param_0) {
    return (getRootVehicle() == param_0.getRootVehicle());
  }
  
  public boolean hasIndirectPassenger(Entity param_0) {
    return getIndirectPassengersStream().anyMatch(param_1 -> (param_1 == param_0));
  }
  
  public boolean isControlledByLocalInstance() {
    Entity var_0 = getControllingPassenger();
    if (var_0 instanceof Player)
      return ((Player)var_0).isLocalPlayer(); 
    return !this.level.isClientSide;
  }
  
  protected static Vec3 getCollisionHorizontalEscapeVector(double param_0, double param_1, float param_2) {
    double var_0 = (param_0 + param_1 + 9.999999747378752E-6D) / 2.0D;
    float var_1 = -Mth.sin(param_2 * 0.017453292F);
    float var_2 = Mth.cos(param_2 * 0.017453292F);
    float var_3 = Math.max(Math.abs(var_1), Math.abs(var_2));
    return new Vec3(var_1 * var_0 / var_3, 0.0D, var_2 * var_0 / var_3);
  }
  
  public Vec3 getDismountLocationForPassenger(LivingEntity param_0) {
    return new Vec3(getX(), (getBoundingBox()).maxY, getZ());
  }
  
  @Nullable
  public Entity getVehicle() {
    return this.vehicle;
  }
  
  public PushReaction getPistonPushReaction() {
    return PushReaction.NORMAL;
  }
  
  public SoundSource getSoundSource() {
    return SoundSource.NEUTRAL;
  }
  
  protected int getFireImmuneTicks() {
    return 1;
  }
  
  public CommandSourceStack createCommandSourceStack() {
    return new CommandSourceStack(this, position(), getRotationVector(), (this.level instanceof ServerLevel) ? (ServerLevel)this.level : null, getPermissionLevel(), getName().getString(), getDisplayName(), this.level.getServer(), this);
  }
  
  protected int getPermissionLevel() {
    return 0;
  }
  
  public boolean hasPermissions(int param_0) {
    return (getPermissionLevel() >= param_0);
  }
  
  public boolean acceptsSuccess() {
    return this.level.getGameRules().getBoolean(GameRules.RULE_SENDCOMMANDFEEDBACK);
  }
  
  public boolean acceptsFailure() {
    return true;
  }
  
  public boolean shouldInformAdmins() {
    return true;
  }
  
  public void lookAt(EntityAnchorArgument.Anchor param_0, Vec3 param_1) {
    Vec3 var_0 = param_0.apply(this);
    double var_1 = param_1.x - var_0.x;
    double var_2 = param_1.y - var_0.y;
    double var_3 = param_1.z - var_0.z;
    double var_4 = Math.sqrt(var_1 * var_1 + var_3 * var_3);
    setXRot(Mth.wrapDegrees((float)-(Mth.atan2(var_2, var_4) * 57.2957763671875D)));
    setYRot(Mth.wrapDegrees((float)(Mth.atan2(var_3, var_1) * 57.2957763671875D) - 90.0F));
    setYHeadRot(getYRot());
    this.xRotO = getXRot();
    this.yRotO = getYRot();
  }
  
  public boolean updateFluidHeightAndDoFluidPushing(Tag<Fluid> param_0, double param_1) {
    if (touchingUnloadedChunk())
      return false; 
    AABB var_0 = getBoundingBox().deflate(0.001D);
    int var_1 = Mth.floor(var_0.minX);
    int var_2 = Mth.ceil(var_0.maxX);
    int var_3 = Mth.floor(var_0.minY);
    int var_4 = Mth.ceil(var_0.maxY);
    int var_5 = Mth.floor(var_0.minZ);
    int var_6 = Mth.ceil(var_0.maxZ);
    double var_7 = 0.0D;
    boolean var_8 = isPushedByFluid();
    boolean var_9 = false;
    Vec3 var_10 = Vec3.ZERO;
    int var_11 = 0;
    BlockPos.MutableBlockPos var_12 = new BlockPos.MutableBlockPos();
    for (int var_13 = var_1; var_13 < var_2; var_13++) {
      for (int var_14 = var_3; var_14 < var_4; var_14++) {
        for (int var_15 = var_5; var_15 < var_6; var_15++) {
          var_12.set(var_13, var_14, var_15);
          FluidState var_16 = this.level.getFluidState((BlockPos)var_12);
          if (var_16.is(param_0)) {
            double var_17 = (var_14 + var_16.getHeight((BlockGetter)this.level, (BlockPos)var_12));
            if (var_17 >= var_0.minY) {
              var_9 = true;
              var_7 = Math.max(var_17 - var_0.minY, var_7);
              if (var_8) {
                Vec3 var_18 = var_16.getFlow((BlockGetter)this.level, (BlockPos)var_12);
                if (var_7 < 0.4D)
                  var_18 = var_18.scale(var_7); 
                var_10 = var_10.add(var_18);
                var_11++;
              } 
            } 
          } 
        } 
      } 
    } 
    if (var_10.length() > 0.0D) {
      if (var_11 > 0)
        var_10 = var_10.scale(1.0D / var_11); 
      if (!(this instanceof Player))
        var_10 = var_10.normalize(); 
      Vec3 var_19 = getDeltaMovement();
      var_10 = var_10.scale(param_1 * 1.0D);
      double var_20 = 0.003D;
      if (Math.abs(var_19.x) < 0.003D && Math.abs(var_19.z) < 0.003D && var_10.length() < 0.0045000000000000005D)
        var_10 = var_10.normalize().scale(0.0045000000000000005D); 
      setDeltaMovement(getDeltaMovement().add(var_10));
    } 
    this.fluidHeight.put(param_0, var_7);
    return var_9;
  }
  
  public boolean touchingUnloadedChunk() {
    AABB var_0 = getBoundingBox().inflate(1.0D);
    int var_1 = Mth.floor(var_0.minX);
    int var_2 = Mth.ceil(var_0.maxX);
    int var_3 = Mth.floor(var_0.minZ);
    int var_4 = Mth.ceil(var_0.maxZ);
    return !this.level.hasChunksAt(var_1, var_3, var_2, var_4);
  }
  
  public double getFluidHeight(Tag<Fluid> param_0) {
    return this.fluidHeight.getDouble(param_0);
  }
  
  public double getFluidJumpThreshold() {
    return (getEyeHeight() < 0.4D) ? 0.0D : 0.4D;
  }
  
  public final float getBbWidth() {
    return this.dimensions.width;
  }
  
  public final float getBbHeight() {
    return this.dimensions.height;
  }
  
  public EntityDimensions getDimensions(Pose param_0) {
    return this.type.getDimensions();
  }
  
  public Vec3 position() {
    return this.position;
  }
  
  public BlockPos blockPosition() {
    return this.blockPosition;
  }
  
  public BlockState getFeetBlockState() {
    return this.level.getBlockState(blockPosition());
  }
  
  public BlockPos eyeBlockPosition() {
    return new BlockPos(getEyePosition(1.0F));
  }
  
  public ChunkPos chunkPosition() {
    return new ChunkPos(this.blockPosition);
  }
  
  public Vec3 getDeltaMovement() {
    return this.deltaMovement;
  }
  
  public void setDeltaMovement(Vec3 param_0) {
    this.deltaMovement = param_0;
  }
  
  public void setDeltaMovement(double param_0, double param_1, double param_2) {
    setDeltaMovement(new Vec3(param_0, param_1, param_2));
  }
  
  public final int getBlockX() {
    return this.blockPosition.getX();
  }
  
  public final double getX() {
    return this.position.x;
  }
  
  public double getX(double param_0) {
    return this.position.x + getBbWidth() * param_0;
  }
  
  public double getRandomX(double param_0) {
    return getX((2.0D * this.random.nextDouble() - 1.0D) * param_0);
  }
  
  public final int getBlockY() {
    return this.blockPosition.getY();
  }
  
  public final double getY() {
    return this.position.y;
  }
  
  public double getY(double param_0) {
    return this.position.y + getBbHeight() * param_0;
  }
  
  public double getRandomY() {
    return getY(this.random.nextDouble());
  }
  
  public double getEyeY() {
    return this.position.y + this.eyeHeight;
  }
  
  public final int getBlockZ() {
    return this.blockPosition.getZ();
  }
  
  public final double getZ() {
    return this.position.z;
  }
  
  public double getZ(double param_0) {
    return this.position.z + getBbWidth() * param_0;
  }
  
  public double getRandomZ(double param_0) {
    return getZ((2.0D * this.random.nextDouble() - 1.0D) * param_0);
  }
  
  public final void setPosRaw(double param_0, double param_1, double param_2) {
    if (this.position.x != param_0 || this.position.y != param_1 || this.position.z != param_2) {
      this.position = new Vec3(param_0, param_1, param_2);
      int var_0 = Mth.floor(param_0);
      int var_1 = Mth.floor(param_1);
      int var_2 = Mth.floor(param_2);
      if (var_0 != this.blockPosition.getX() || var_1 != this.blockPosition.getY() || var_2 != this.blockPosition.getZ())
        this.blockPosition = new BlockPos(var_0, var_1, var_2); 
      this.levelCallback.onMove();
      GameEventListenerRegistrar var_3 = getGameEventListenerRegistrar();
      if (var_3 != null)
        var_3.onListenerMove(this.level); 
    } 
  }
  
  public void checkDespawn() {}
  
  public Vec3 getRopeHoldPosition(float param_0) {
    return getPosition(param_0).add(0.0D, this.eyeHeight * 0.7D, 0.0D);
  }
  
  public void recreateFromPacket(ClientboundAddEntityPacket param_0) {
    int var_0 = param_0.getId();
    double var_1 = param_0.getX();
    double var_2 = param_0.getY();
    double var_3 = param_0.getZ();
    setPacketCoordinates(var_1, var_2, var_3);
    moveTo(var_1, var_2, var_3);
    setXRot((param_0.getxRot() * 360) / 256.0F);
    setYRot((param_0.getyRot() * 360) / 256.0F);
    setId(var_0);
    setUUID(param_0.getUUID());
  }
  
  @Nullable
  public ItemStack getPickResult() {
    return null;
  }
  
  public void setIsInPowderSnow(boolean param_0) {
    this.isInPowderSnow = param_0;
  }
  
  public boolean canFreeze() {
    return !EntityTypeTags.FREEZE_IMMUNE_ENTITY_TYPES.contains(getType());
  }
  
  public float getYRot() {
    return this.yRot;
  }
  
  public void setYRot(float param_0) {
    if (!Float.isFinite(param_0)) {
      Util.logAndPauseIfInIde("Invalid entity rotation: " + param_0 + ", discarding.");
      return;
    } 
    this.yRot = param_0;
  }
  
  public float getXRot() {
    return this.xRot;
  }
  
  public void setXRot(float param_0) {
    if (!Float.isFinite(param_0)) {
      Util.logAndPauseIfInIde("Invalid entity rotation: " + param_0 + ", discarding.");
      return;
    } 
    this.xRot = param_0;
  }
  
  public final boolean isRemoved() {
    return (this.removalReason != null);
  }
  
  @Nullable
  public RemovalReason getRemovalReason() {
    return this.removalReason;
  }
  
  public final void setRemoved(RemovalReason param_0) {
    if (this.removalReason == null)
      this.removalReason = param_0; 
    if (this.removalReason.shouldDestroy())
      stopRiding(); 
    getPassengers().forEach(Entity::stopRiding);
    this.levelCallback.onRemove(param_0);
  }
  
  protected void unsetRemoved() {
    this.removalReason = null;
  }
  
  @FunctionalInterface
  public static interface MoveFunction {
    void accept(Entity param1Entity, double param1Double1, double param1Double2, double param1Double3);
  }
  
  public enum MovementEmission {
    NONE(false, false),
    SOUNDS(true, false),
    EVENTS(false, true),
    ALL(true, true);
    
    final boolean sounds;
    
    final boolean events;
    
    MovementEmission(boolean param_0, boolean param_1) {
      this.sounds = param_0;
      this.events = param_1;
    }
    
    public boolean emitsAnything() {
      return (this.events || this.sounds);
    }
    
    public boolean emitsEvents() {
      return this.events;
    }
    
    public boolean emitsSounds() {
      return this.sounds;
    }
  }
  
  public enum RemovalReason {
    KILLED(true, false),
    DISCARDED(true, false),
    UNLOADED_TO_CHUNK(false, true),
    UNLOADED_WITH_PLAYER(false, false),
    CHANGED_DIMENSION(false, false);
    
    private final boolean destroy;
    
    private final boolean save;
    
    RemovalReason(boolean param_0, boolean param_1) {
      this.destroy = param_0;
      this.save = param_1;
    }
    
    public boolean shouldDestroy() {
      return this.destroy;
    }
    
    public boolean shouldSave() {
      return this.save;
    }
  }
  
  public void setLevelCallback(EntityInLevelCallback param_0) {
    this.levelCallback = param_0;
  }
  
  public boolean shouldBeSaved() {
    if (this.removalReason != null && !this.removalReason.shouldSave())
      return false; 
    if (isPassenger())
      return false; 
    if (isVehicle() && hasExactlyOnePlayerPassenger())
      return false; 
    return true;
  }
  
  public boolean isAlwaysTicking() {
    return false;
  }
  
  public boolean mayInteract(Level param_0, BlockPos param_1) {
    return true;
  }
  
  protected abstract void defineSynchedData();
  
  protected abstract void readAdditionalSaveData(CompoundTag paramCompoundTag);
  
  protected abstract void addAdditionalSaveData(CompoundTag paramCompoundTag);
  
  public abstract Packet<?> getAddEntityPacket();
}

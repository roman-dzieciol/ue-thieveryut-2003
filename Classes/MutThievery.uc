/* ============================================================================
:: MutThievery ::
:: ============================================================================
:: Copyright © 2002 Thievery Team :::::::::::::::: http://www.thieveryut.com ::
============================================================================ */
class MutThievery extends Mutator;

/* ============================================================================
:: Variables ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
struct LightDebug
{
	var() name LightName;
	var() float LightMod;
	var() float Tx, Ty, Tz, TD, TM, TLB , distance,lightdistance;
};

var() array<LightDebug>	LightsDebug;
var() int ActorCounter;

var RawMaterialFactory RMF;
var() float TotalVis,TargetVis, LightVis, MovVis;
var() float TVis;
var() float LightDebugModifier, LightModifier;
var() float UpdateFrequency;

/* ============================================================================
:: PreBeginPlay :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
event PreBeginPlay()
{
	RMF = New(None) Class'Editor.RawMaterialFactory';

	if(RMF != None)
	{
		SetTimer(UpdateFrequency,true);
		Log("SUCCESS :: RMF");

		// debug materials for use with EditObj
		CreateMaterial(None, "MyLevel", "", "FinalBlendTest", Class'Engine.FinalBlend');
		CreateMaterial(None, "MyLevel", "", "ColorModifierTest", Class'Engine.ColorModifier');
		CreateMaterial(None, "MyLevel", "", "OpacityModifierTest", Class'Engine.OpacityModifier');
		CreateMaterial(None, "MyLevel", "", "ShaderTest", Class'Engine.Shader');
		CreateMaterial(None, "MyLevel", "", "CombinerTest", Class'Engine.Combiner');
		CreateMaterial(None, "MyLevel", "", "ConstantColorTest", Class'Engine.ConstantColor');
	}
	else
	{
		Log("ERROR :: RMF == None");
		return;
	}
}

/* ============================================================================
:: Timer ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function Timer()
{
	local Controller C;
	local int i;

	for (C = Level.ControllerList; C != None; C = C.NextController)
	{
		if (C.Pawn == None)			continue;
		if (xPawn(C.Pawn) == None)	continue;

		// Adjust visibility of player's shadow
		AdjustShadow(xPawn(C.Pawn), TVis);

		// Calculate visibility of this player
		CalculateVisibility(xPawn(C.Pawn));

		for (i=0; i<C.Pawn.Skins.Length; i++)
		{
			if (TM_FinalBlend(C.Pawn.Skins[i]) != None)
			{
				// Change opacity of player's skin
				AdjustSkin(TM_FinalBlend(C.Pawn.Skins[i]), TVis);
			}
			else
			{
				// Create adjustable skin
				PrepareSkin(C.Pawn.Skins[i]);
			}
		}
	}
}
/* ============================================================================
:: Tick :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
event Tick( float DeltaTime )
{
	local float LastUpdate, DeltaVis;

	// X .5 0.0

	// X .7 0.25



	LastUpdate

}

/* ============================================================================
:: PrepareSkin ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function PrepareSkin( out material PlayerSkin )
{
	local TM_ColorModifier CM;
	local TM_FinalBlend	FB;

	Log("##### PrepareSkin :: "$PlayerSkin, 'ThieveryUT');

	// create modifiers
	CM = TM_ColorModifier(CreateMaterial(None, "MyLevel", "", "", Class'Thievery2003Mutator.TM_ColorModifier'));
	FB = TM_FinalBlend(CreateMaterial(None, "MyLevel", "", "", Class'Thievery2003Mutator.TM_FinalBlend'));

	// setup materials
	FB.FrameBufferBlending = FB_AlphaBlend;
	FB.Material = CM;
	CM.Material = PlayerSkin;
	CM.RenderTwoSided = false;
	CM.AlphaBlend = false;

	// replace player's skin with a modifier
	PlayerSkin = FB;
}

/* ============================================================================
:: AdjustSkin :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function AdjustSkin( TM_FinalBlend FB , float Vis)
{
	// Fade skin color to black
	TM_ColorModifier(FB.Material).Color.R = Vis;
	TM_ColorModifier(FB.Material).Color.G = Vis;
	TM_ColorModifier(FB.Material).Color.B = Vis;

	// Fade opacity
	TM_ColorModifier(FB.Material).Color.A = Vis;
}

/* ============================================================================
:: AdjustShadow :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function AdjustShadow( xPawn P , float Vis)
{
	if ((P.PlayerShadow != None) && (P.PlayerShadow.ShadowTexture != None))
	{
		P.PlayerShadow.ShadowTexture.ShadowDarkness = Vis;
	}
}

/* ============================================================================
:: MapValue :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function float MapValue( float inValue, float inRange, float inChange )
{
	return inValue*(inChange/inRange);
}

/* ============================================================================
:: CreateMaterial :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function Material CreateMaterial( Object InOuter, string InPackage, string InGroup, string InName, Class<Material> MC )
{
	RMF.MaterialClass = MC;
	return RMF.CreateMaterial(InOuter, InPackage, InGroup, InName);
}

/* ============================================================================
:: CalculateVisibility ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function CalculateVisibility( xPawn TPP )
{
	local vector Loc;

//	Log("##### CalculateVisibility :: "$P, 'ThieveryUT');

	// Init
	Loc = TPP.Location;
	TPP.AmbientGlow=0;
	TargetVis = 0;
	LightVis = 0;
	MovVis = 0;

    TargetVis += Vis_Movement(TPP, Loc);
	TargetVis += Vis_Lighting(TPP, Loc);

	TargetVis = FClamp(TargetVis,0,1);

	// Set visibility, affects bots (slightly).
	TPP.Visibility = TPP.Default.Visibility * TargetVis;

	// Calculate final visibility level
	TVis = Clamp(Round(MapValue(TargetVis, 1, 255)), 0, 255);
}

/* ============================================================================
:: Vis_Movement :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function float Vis_Movement( xPawn TPP, out vector Loc )
{
	// Brightness mod due to crouching
	// lower vis by 10% and lower the raytrace point.
	// Values are still a bit experimental.
	if (TPP.bIsCrouched)
	{
		MovVis -= 0.1;
//		Loc.z -= 30;
	}

	// Brightness mod due to movement
	// Vsize(TPP.Velocity) usually ranges from 0-400 but can go higher when jumping/being shot around
	// I've mapped this 0-400 change to a 0 to 0.20 change in TotalVis
	MovVis += MapValue(VSize(TPP.Velocity), TPP.Default.GroundSpeed, 0.20);

	return MovVis;
}

/* ============================================================================
:: Vis_Lighting :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
============================================================================ */
function float Vis_Lighting( xPawn TPP, out vector Loc )
{
	local Actor TL;
	local int i;
	local float SpotAngle;
	local float Tx, Ty, Tz, TD, TM, TLB , distance,lightdistance;

	ActorCounter = 0;
    LightsDebug.Length = 0;

	// Checks to determine brightness of player
	foreach AllActors ( class'Actor', TL,)
	{
		// DEBUG :: let's see how many actors we're processing in each frame
		ActorCounter++;

		// actor is a light of some kind
		if ((TL.LightType != LT_None) && (!TL.bSpecialLit) && (TL.Tag!='NoLightPlayer'))
		{

            // a spotlight
			if ((TL.LightEffect==LE_SpotLight) || (TL.LightEffect==LE_StaticSpot))
			{
				SpotAngle = Normal(TPP.Location-TL.Location) dot Normal(vector(TL.Rotation));

				// spotlight facing player
				if (SpotAngle>(255.0 - TL.LightCone)/255.0)
				{
					Tx = ( TL.Location.x - Loc.x) * ( TL.Location.x - Loc.x);
					Ty = ( TL.Location.y - Loc.y) * ( TL.Location.y - Loc.y);
					Tz = ( TL.Location.z - Loc.z) * ( TL.Location.z - Loc.z);
					TD = Tx + Ty + Tz;

					TLB = TL.LightBrightness * TL.LightRadius;

					if ( TD*0.0001 < TLB )
					{
						// radius check add check
						if (TD < LightDebugModifier * TL.LightRadius)
						{

							if ( FastTrace( TL.Location, Loc ) && ( LightVis != 1 ) )
							{
								TM = TLB/TD;
								TM*=0.5+(0.5*(SpotAngle-((255.0 - TL.LightCone)/255.0))/(1-(255.0 - TL.LightCone)/255.0));
								LightVis += (TM*15)*LightModifier;

								// debug
								LightsDebug[i].LightName = TL.class.name;
								LightsDebug[i].TD = TD;
								LightsDebug[i].TM = TM;
								LightsDebug[i].TLB = TLB;
								LightsDebug[i].LightMod = (TM*15)*LightModifier;
								i++;

								if ( LightVis > 1 )
								{
									//player at full bright, no more calcs needed
									LightVis = 1;
									return LightVis;
								}
							}
						}
					}
				}
			}
			else
			{
				// dalai's algo (mit info von Tim Sweeney)
				distance = VSize(TL.Location-Loc);
				lightdistance = TL.LightRadius*25;

				if (distance < lightdistance)
				{
					if ( FastTrace( TL.Location, Loc ) && ( LightVis != 1 ) )
					{
						// debug
						LightsDebug[i].LightName = TL.class.name;
						LightsDebug[i].distance = distance;
						LightsDebug[i].lightdistance = lightdistance;
						LightsDebug[i].LightMod = (0.025*TL.LightBrightness*(1.0-(distance/lightdistance)))*LightModifier;
                        i++;

						LightVis += (0.025*TL.LightBrightness*(1.0-(distance/lightdistance)))*LightModifier;
						if ( LightVis > 1 )
						{
							//player at full bright, no more calcs needed
							LightVis = 1;
							return LightVis;
						}
					}
				}
			}
		}
	}

	return LightVis;
}

/*
	ConfigMenuClassName=""
	GroupName="Thievery"
	FriendlyName="Thievery Mutator"
	Description="Alpha 1 :: All players skins have 50% translucency."
*/

/*
:: End of MutThievery ::
============================================================================ */
DefaultProperties
{
	LightDebugModifier=8100
	UpdateFrequency=0.3
	LightModifier=0.2
}

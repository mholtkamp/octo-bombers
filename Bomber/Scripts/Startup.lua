
BomberCollision = 
{
    Default = 0x01,
    Environment = 0x02,
    Bomber = 0x04,
    Bomb = 0x08,
    Trigger = 0x10,
}

ObjectType = 
{
    None = 0,
    Block = 1,
    Tree = 2,
    Bomb = 3,
    Box1 = 4,
    Box2 = 5,
    Box3 = 6,
}

PowerupType =
{
    BombCount = 1,
    BombRange = 2,
    MoveSpeed = 3,

    Count = 3,   
}

Script.Require("GameState.lua")
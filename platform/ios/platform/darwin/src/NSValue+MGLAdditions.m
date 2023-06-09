#import "NSValue+MGLAdditions.h"

@implementation NSValue (MGLAdditions)

// MARK: Geometry

+ (instancetype)valueWithMGLCoordinate:(CLLocationCoordinate2D)coordinate {
    return [self valueWithBytes:&coordinate objCType:@encode(CLLocationCoordinate2D)];
}

- (CLLocationCoordinate2D)MGLCoordinateValue {
    CLLocationCoordinate2D coordinate;
    [self getValue:&coordinate];
    return coordinate;
}

+ (instancetype)valueWithMGLMapPoint:(MGLMapPoint)point {
    return [self valueWithBytes:&point objCType:@encode(MGLMapPoint)];
}

-(MGLMapPoint) MGLMapPointValue {
    MGLMapPoint point;
    [self getValue:&point];
    return point;
}

+ (instancetype)valueWithMGLCoordinateSpan:(MGLCoordinateSpan)span {
    return [self valueWithBytes:&span objCType:@encode(MGLCoordinateSpan)];
}

- (MGLCoordinateSpan)MGLCoordinateSpanValue {
    MGLCoordinateSpan span;
    [self getValue:&span];
    return span;
}

+ (instancetype)valueWithMGLCoordinateBounds:(MGLCoordinateBounds)bounds {
    return [self valueWithBytes:&bounds objCType:@encode(MGLCoordinateBounds)];
}

- (MGLCoordinateBounds)MGLCoordinateBoundsValue {
    MGLCoordinateBounds bounds;
    [self getValue:&bounds];
    return bounds;
}

+ (instancetype)valueWithMGLCoordinateQuad:(MGLCoordinateQuad)quad {
    return [self valueWithBytes:&quad objCType:@encode(MGLCoordinateQuad)];
}

- (MGLCoordinateQuad)MGLCoordinateQuadValue {
    MGLCoordinateQuad quad;
    [self getValue:&quad];
    return quad;
}

// MARK: Offline maps

+ (NSValue *)valueWithMGLOfflinePackProgress:(MGLOfflinePackProgress)progress {
    return [NSValue value:&progress withObjCType:@encode(MGLOfflinePackProgress)];
}

- (MGLOfflinePackProgress)MGLOfflinePackProgressValue {
    MGLOfflinePackProgress progress;
    [self getValue:&progress];
    return progress;
}

// MARK: Working with Transition Values

+ (NSValue *)valueWithMGLTransition:(MGLTransition)transition {
    return [NSValue value:&transition withObjCType:@encode(MGLTransition)];
}

- (MGLTransition)MGLTransitionValue {
    MGLTransition transition;
    [self getValue:&transition];
    return transition;
}

+ (NSValue *)valueWithMGLSphericalPosition:(MGLSphericalPosition)lightPosition
{
    return [NSValue value:&lightPosition withObjCType:@encode(MGLSphericalPosition)];
}

- (MGLSphericalPosition)MGLSphericalPositionValue
{
    MGLSphericalPosition lightPosition;
    [self getValue:&lightPosition];
    return lightPosition;
}

+ (NSValue *)valueWithMGLLightAnchor:(MGLLightAnchor)lightAnchor {
    return [NSValue value:&lightAnchor withObjCType:@encode(MGLLightAnchor)];
}

- (MGLLightAnchor)MGLLightAnchorValue
{
    MGLLightAnchor achorType;
    [self getValue:&achorType];
    return achorType;
}

@end

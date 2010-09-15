//
//  SGStylesViewController.m
//  SGARViewStyles
//
//  Copyright (c) 2009-2010, SimpleGeo
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, 
//  this list of conditions and the following disclaimer. Redistributions 
//  in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or 
//  other materials provided with the distribution.
//  
//  Neither the name of the SimpleGeo nor the names of its contributors may
//  be used to endorse or promote products derived from this software 
//  without specific prior written permission.
//   
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  Created by Derek Smith.
//

#import "SGStylesViewController.h"

/* 
 * Used for interacting with the OpenGLES portion of the AR
 * environment.
 */
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

/*
 * The annotation views that are used in the AR environment.
 */
#import "SGSimpleAnnotation.h"
#import "SGForestAnnotationView.h"
#import "SGDistressedDamselAnnotationView.h"
#import "SGKettleAnnotationView.h"
#import "SGPersonAnnotationView.h"

#define AMOUNT_OF_LOCATIONS             50          // Total amount of locations to use.

/*
 * The styles that the applications shows off.
 */
enum SGARStyle {

    kSGARStyle_Default = 0,
    kSGARStyle_Forest,
    kSGARStyle_DID,
    kSGARStyle_Kettleland,
    kSGARStyle_BigRadar,
    
    kSGARStyle_Amount
};

typedef NSInteger SGARStyle;

@interface SGStylesViewController (Private) <SGARViewControllerDataSource, CLLocationManagerDelegate, SGARResponder>

- (NSMutableArray*) createLocationPointsBasedOnLocation:(CLLocation*)location amount:(NSInteger)amount;

- (void) configureDefaultStyle;
- (void) configureForestStyle;
- (void) configureDIDStyle;
- (void) configureKettleEscherStyle;
- (void) configureBigRadar;

- (void) resetAREnvironment;
- (void) showMessage;

- (void) stackLeftContainer:(id)c;
- (void) stackEnteredContainer:(id)c;

- (void) changeCardinalDirectionColor:(UIColor*)color font:(UIFont*)font;
- (void) reloadAnnotations;

@end

@implementation SGStylesViewController

- (id) init
{
    if(self = [super init]) {
        
        // This table will be used to allow the user to switch styles.
        stylesTableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, 50.0, 320.0, 250.0) style:UITableViewStyleGrouped];
        stylesTableView.backgroundColor = [UIColor clearColor];
        stylesTableView.delegate = self;
        stylesTableView.dataSource = self;

        arViewController = [[SGARViewController alloc] init];

#if __IPHONE_4_0 >= __IPHONE_OS_VERSION_MAX_ALLOWED

        arNavigationController = [[UINavigationController alloc] initWithRootViewController:arViewController];

#else
        
        arNavigationController = arViewController;

#endif

        arViewController.dataSource = self;

        // Remove the default "Done" bar button
        arNavigationController.navigationItem.rightBarButtonItem = nil;
        
        // We want to be notified when touch events occur within the AR environment.
        [arViewController.arView addResponder:self];
        
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        [locationManager startUpdatingLocation];        
        
        annotations = [[NSMutableArray alloc] init];
        
        currentStyle = kSGARStyle_Default;
        
        numberOfAnnotations = 0;
                
    }
    
    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIButton methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) changeStyles:(id)b
{
    UIBarButtonItem* button = (UIBarButtonItem*)b;
    
    // If our tag is 0, the styles table view is not being shown. Show it.
    if(!button.tag) {              
        if(!stylesTableView.superview) {
            UIWindow* keyWindow = [[UIApplication sharedApplication] keyWindow];
            [keyWindow addSubview:stylesTableView];   
        }
        button.title = @"Cancel";
        [arViewController.arView stopAnimation]; 
    } else {
        button.title = @"Choose Style";
        [arViewController.arView startAnimation];
    }
    
    stylesTableView.hidden = button.tag;    
    button.tag = !button.tag;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SGAnnotationViewContainer callbacks 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) stackEnteredContainer:(id)c
{
    // Highlight the container
    SGAnnotationViewContainer* container = (SGAnnotationViewContainer*)c;    
    [container setBackgroundImage:[UIImage imageNamed:@"SafeSignHighlighted.png"] forState:UIControlStateNormal];
}

- (void) stackLeftContainer:(id)c
{
    // Unhighlight the container
    SGAnnotationViewContainer* container = (SGAnnotationViewContainer*)c;
    [container setBackgroundImage:[UIImage imageNamed:@"SafeSign.png"] forState:UIControlStateNormal];    
}

- (void) containerDoubleTouch:(id)c
{
    // Present a simple "Thank you" message.
    SGAnnotationViewContainer* container = (SGAnnotationViewContainer*)c;
    if(![container isEmpty]) {
        [self showMessage];
        [container removeAllAnnotationViews];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIViewController overrides 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem* styleButton = [[UIBarButtonItem alloc] initWithTitle:@"Choose Style"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self 
                                                                   action:@selector(changeStyles:)];
    styleButton.possibleTitles = [NSSet setWithObjects:@"Choose Style", @"Cancel", nil];
    styleButton.tag = 0;
    
    arViewController.navigationItem.rightBarButtonItem = styleButton;
    [styleButton release];
    
    safeZone = [[SGAnnotationViewContainer buttonWithType:UIButtonTypeCustom] retain];
    safeZone.frame = CGRectMake(20.0, 300.0, 100.0, 100.0);    
    [safeZone addTarget:self action:@selector(stackEnteredContainer:) forControlEvents:UIControlEventTouchDragEnter];
    [safeZone addTarget:self action:@selector(stackLeftContainer:) forControlEvents:UIControlEventTouchDragExit | UIControlEventTouchUpInside];
    [safeZone addTarget:self action:@selector(showMessage) forControlEvents:UIControlEventTouchDownRepeat];
    [self stackLeftContainer:safeZone];
    
    arViewController.arView.movableStack.maxStackAmount = 1;
    
    [self configureDefaultStyle];    
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self presentModalViewController:arNavigationController animated:NO];
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark CLLocationManager delegate methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) locationManager:(CLLocationManager*)manager didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation
{
    // Only use the first locations as a basis to build the random points.
    if(!oldLocation)
        [self reloadAnnotations];
}

-  (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError*)error
{
    // Don't really care if the location manager fails.
    ;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITableView delegate methods 
////////////////////////////////////////////////////////////////////////////////////////////////

- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
    NSInteger style = indexPath.row;
    
    [self resetAREnvironment];
    
    switch (style) {
        case kSGARStyle_Default:
            [self configureDefaultStyle];
            break;
        case kSGARStyle_Forest:
            [self configureForestStyle];
            break;
        case kSGARStyle_DID:
            [self configureDIDStyle];
            break;
        case kSGARStyle_Kettleland:
            [self configureKettleEscherStyle];
            break;
        case kSGARStyle_BigRadar:
            [self configureBigRadar];
        default:
            break;
    }
    
    currentStyle = style;
    
    [self changeStyles:arViewController.navigationItem.rightBarButtonItem];
    [self reloadAnnotations];    
    [tableView cellForRowAtIndexPath:indexPath].selected = NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITableView delegate methods 
////////////////////////////////////////////////////////////////////////////////////////////////

- (UITableViewCell*) tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"StyleCell"];
    
    if(!cell)
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StyleCell"] autorelease];
    
    NSInteger row = indexPath.row;
    
    switch (row) {
        case kSGARStyle_Default:
            cell.textLabel.text = @"Default";
            break;
        case kSGARStyle_Forest:
            cell.textLabel.text = @"Forest";
            break;
        case kSGARStyle_DID:
            cell.textLabel.text = @"Damsels in Distriss";
            break;
        case kSGARStyle_Kettleland:
            cell.textLabel.text = @"Kettle + Escher";
            break;
        case kSGARStyle_BigRadar:
            cell.textLabel.text = @"Big Radar";
            break;
        default:
            // Nothing.
            break;
    }
    
    cell.textLabel.textAlignment = UITextAlignmentCenter;
    
    return cell;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView*)tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    // Removing the "Big Radar" style for now.
    return kSGARStyle_Amount - 1;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SGARViewController delegate methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (SGAnnotationView*) viewController:(SGARViewController*)nvc
                   viewForAnnotation:(id<MKAnnotation>)annotation 
                       atBucketIndex:(NSInteger)bucketIndex
{
    // Use the annotation views that are specific to the style.
    SGAnnotationView* annotationView = nil;
    switch (currentStyle) {
        case kSGARStyle_Default:
        {
            annotationView = [nvc.arView dequeueReuseableAnnotationViewWithIdentifier:@"Default"];
            if(!annotationView)
                annotationView = [[[SGPinAnnotationView alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0) reuseIdentifier:@"Default"] autorelease];
        }   
            break;
        case kSGARStyle_Forest:
        {
            annotationView = [nvc.arView dequeueReuseableAnnotationViewWithIdentifier:@"Forest"];
            if(!annotationView)
                annotationView = [[[SGForestAnnotationView alloc] initWithFrame:[SGGlassAnnotationView inspectRect] reuseIdentifier:@"Forest"] autorelease];
            
            double distance = [locationManager.location distanceFromLocation:[[CLLocation alloc] initWithCoordinate:annotation.coordinate
                                                                                                           altitude:0.0 
                                                                                                 horizontalAccuracy:0.0 
                                                                                                   verticalAccuracy:0.0
                                                                                                          timestamp:nil]];
            ((SGForestAnnotationView*)annotationView).detailedLabel.text = [NSString stringWithFormat:@"%.1fm", distance / 10.0];
            
            break;
        }   
        case kSGARStyle_DID:
        {
            if(rand() % 3 == 1) { 
                annotationView = [nvc.arView dequeueReuseableAnnotationViewWithIdentifier:@"Sparky"];
                if(!annotationView) {
                    annotationView = [[[SGGargoyleAnnotationView alloc] initWithFrame:[SGGlassAnnotationView targetRect] reuseIdentifier:@"Sparky"] autorelease];
                    ((SGGargoyleAnnotationView*)annotationView).anchorManager = locationManager;
                }
            } else {                
                annotationView = [nvc.arView dequeueReuseableAnnotationViewWithIdentifier:@"DID"];
                if(!annotationView)
                    annotationView = [[[SGDistressedDamselAnnotationView alloc] initWithFrame:[SGGlassAnnotationView targetRect] reuseIdentifier:@"DID"] autorelease];
            }
                        
            break;
        }
        case kSGARStyle_Kettleland:
        {
            annotationView = [nvc.arView dequeueReuseableAnnotationViewWithIdentifier:@"Kettle"];
            if(!annotationView)
                annotationView = [[[SGKettleAnnotationView alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0) reuseIdentifier:@"Kettle"] autorelease];
            
            break;
        }
        case kSGARStyle_BigRadar:
        {
            annotationView = [nvc.arView dequeueReuseableAnnotationViewWithIdentifier:@"BigRadar"];
            if(!annotationView)
                annotationView = [[[SGPersonAnnotationView alloc] initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0) reuseIdentifier:@"BigRadar"] autorelease];
            
            break;
        }   
        default:
            break;
    }
    
    if(annotationView) {
        annotationView.annotation = annotation;
        annotationView.delegate = self;
    }
        
    return annotationView;
}

- (NSArray*) viewController:(SGARViewController*)nvc annotationsForBucketAtIndex:(NSInteger)bucketIndex
{
    return annotations;
}

- (NSInteger) viewControllerNumberOfBuckets:(SGARViewController*)nvc
{
    return 1;
}

- (void) reloadAnnotations
{
    [annotations removeAllObjects];
    
    NSArray* locations = [self createLocationPointsBasedOnLocation:locationManager.location amount:numberOfAnnotations];
    for(CLLocation* location in locations)
        [annotations addObject:[[[SGSimpleAnnotation alloc] initWithLocation:location.coordinate] autorelease]];
    
    [arViewController reloadAllBuckets];
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Style configure methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

/*
 * The default style will use many of the default style settings
 * within the AR environment. A simple pin image will be used for
 * SGAnnotationViews.
 */
- (void) configureDefaultStyle
{
    numberOfAnnotations = 10;
    
    SGARView* arView = arViewController.arView;
    arView.enableGridLines = YES;
    arView.gridLineColor = [UIColor blueColor];
    arView.movableStack.maxStackAmount = 0;
    
    SGRadar* radar = arView.radar;
    radar.shouldShowCardinalDirections = YES;
    radar.rotatable = NO;
    
    [self changeCardinalDirectionColor:[UIColor whiteColor] font:[UIFont boldSystemFontOfSize:12.0]];
    
    // This will assure that all annotation views are appear to 
    // be within 50 meters.
    SGSetEnvironmentMaximumAnnotationDistance(50.0f);
    SGSetEnvironmentMinimumAnnotationDistance(50.0f);
    
    arViewController.title = @"Default";
    [arNavigationController setToolbarHidden:NO animated:NO];    
    arNavigationController.navigationBar.tintColor = [UIColor blackColor];
    arNavigationController.navigationBar.translucent = YES;
    arNavigationController.toolbar.tintColor = [UIColor blackColor];
    arNavigationController.toolbar.translucent = YES;
}

/*
 * Shows off a different target style for annotation views.
 */
- (void) configureForestStyle
{
    numberOfAnnotations = 10;
    
    SGARView* arView = arViewController.arView;
    
    // Disable the movable staack
    arView.movableStack.maxStackAmount = 0;
    SGRadar* radar = arView.radar;
    radar.rotatable = NO;
    
    radar.cardinalDirectionOffset = 5.0f;
    [self changeCardinalDirectionColor:[UIColor brownColor] font:[UIFont boldSystemFontOfSize:24.0]];
    
    SGSetEnvironmentMinimumAnnotationDistance(10.0f);
    
    arViewController.title = @"Forest";
    [arNavigationController setToolbarHidden:NO animated:NO];    
    arNavigationController.navigationBar.tintColor = [UIColor colorWithRed:103.0/255.0 green:131.0/255.0 blue:16.0/255.0 alpha:1.0];
    arNavigationController.toolbar.tintColor = [UIColor colorWithRed:103.0/255.0 green:131.0/255.0 blue:16.0/255.0 alpha:1.0];
}

/*
 * Displays annotations that dynamically update their posititon while
 * enabling the movable stack and container.
 */
- (void) configureDIDStyle
{
    numberOfAnnotations = 20;
        
    SGARView* arView = arViewController.arView;
    arView.movableStack.maxStackAmount = 3;
    arView.enableWalking = YES;
    [arView addContainer:safeZone];
    
    // Updgrade the radar to reflect the style.
    SGRadar* radar = arView.radar;
    radar.shouldShowCardinalDirections = NO;
    radar.rotatable = NO;
    radar.radarBackgroundImageView.image = [UIImage imageNamed:@"DIDRadarBackground.png"];
    UIImage* image = [UIImage imageNamed:@"DIDRadarHeading.png"];
    radar.headingImageView.image = image;
    radar.headingImageView.frame = CGRectMake(0.0, 0.0, image.size.width + 5.0, image.size.height);
    radar.currentLocationImageView.image = [UIImage imageNamed:@"DIDCurrentLocationRadarTarget.png"];
    
    // Create a boundary of 10 meters.
    SGSetEnvironmentMinimumAnnotationDistance(10.0f);
    
    arViewController.title = @"Damsels in Distress";
    [arNavigationController setToolbarHidden:YES animated:NO];
    arNavigationController.navigationBar.tintColor = [UIColor colorWithRed:0.0 green:136.0/255.0 blue:219.0/255.0 alpha:1.0];
    arNavigationController.toolbar.tintColor = [UIColor colorWithRed:0.0 green:136.0/255.0 blue:219.0/255.0 alpha:1.0];
    
}

- (void) configureKettleEscherStyle
{
    numberOfAnnotations = 20;
    
    SGARView* arView = arViewController.arView;
    arView.enableWalking = YES;
    [arView removeContainer:safeZone];
    
    // We don't want our teapots getting too far away from us.
    SGSetEnvironmentMaximumAnnotationDistance(70.0f);
    
    // Setup a simple lightin environment to give the teapots
    // a little shininess.
    const GLfloat lightAmbient[] = {0.2, 0.2, 0.2, 1.0};
	const GLfloat lightDiffuse[] = {1.0, 0.6, 0.0, 1.0};
	const GLfloat matAmbient[] = {0.6, 0.6, 0.6, 1.0};
	const GLfloat matDiffuse[] = {1.0, 1.0, 1.0, 1.0};	
	const GLfloat matSpecular[] = {1.0, 1.0, 1.0, 1.0};
	const GLfloat lightPosition[] = {0.0, 0.0, 1.0, 0.0}; 
	const GLfloat lightShininess = 100.0;
	
	glEnable(GL_LIGHTING);
	glEnable(GL_LIGHT0);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, matAmbient);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, matDiffuse);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, matSpecular);
	glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, lightShininess);
	glLightfv(GL_LIGHT0, GL_AMBIENT, lightAmbient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, lightDiffuse);
	glLightfv(GL_LIGHT0, GL_POSITION, lightPosition); 			
	glShadeModel(GL_SMOOTH);
        
    arViewController.title = @"Escher + Kettle";
    arNavigationController.navigationBar.tintColor = [UIColor colorWithRed:255.0/255.0 green:112.0/255.0 blue:62.0/255.0 alpha:1.0];
    [arNavigationController setToolbarHidden:YES animated:NO];
}

- (void) configureBigRadar
{
    numberOfAnnotations = 4;
    
    SGARView* arView = arViewController.arView;
    arView.enableWalking = NO;
    arView.enableGridLines = NO;
    [arView removeContainer:safeZone];
    
    SGSetEnvironmentViewingRadius(100.0f);
    SGSetEnvironmentMaximumAnnotationDistance(100.0f);
    SGSetEnvironmentMinimumAnnotationDistance(2.0f);
    
    SGRadar* radar = arView.radar;
    
    CGFloat size = 200.0;
    radar.frame = CGRectMake((self.view.bounds.size.width - size) / 2.0,
                             (self.view.bounds.size.height - size) / 2.0,
                             size, size);    
    
    arViewController.title = @"Big Radar";
    arNavigationController.navigationBar.tintColor = [UIColor blackColor];
    arNavigationController.navigationBar.translucent = YES;
    [arNavigationController setToolbarHidden:NO animated:YES];
    
    glDisable(GL_LIGHTING);
}
 
////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SGAnnotationView delegate methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (UIView*) shouldInspectAnnotationView:(SGAnnotationView*)annotationView
{    
    UIView* viewToInspect = nil;
    if(currentStyle == kSGARStyle_Forest) {
        ((SGForestAnnotationView*)annotationView).inspectionMode = YES;
        viewToInspect = annotationView;
        CGRect inspectRect = [SGGlassAnnotationView inspectRect];
        viewToInspect.frame = CGRectMake((self.view.bounds.size.width - inspectRect.size.width) / 2.0, 
                                         50.0,
                                         inspectRect.size.width,
                                         inspectRect.size.height);
    } else if(currentStyle == kSGARStyle_DID) {
        if([annotationView isKindOfClass:[SGDistressedDamselAnnotationView class]]) {
            SGDistressedDamselAnnotationView* did = (SGDistressedDamselAnnotationView*)annotationView;
            did.frame = !did.inspectionMode ? [SGGlassAnnotationView inspectRect] : [SGGlassAnnotationView targetRect];            
            did.inspectionMode = !did.inspectionMode;

            // Notice how we do not return this view.
            // We still want this view to reside in the AR environment
            // and not as a subview of ARView.
        }
    }
    
    return viewToInspect;
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SGARResponder methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) viewDidShake
{
    // Release all of the captured annotation views from
    // the container.
    if(currentStyle == kSGARStyle_DID) {
        NSArray* containers = [arViewController.arView getContainers];
        for(SGAnnotationViewContainer* container in  containers)
            [container removeAllAnnotationViews];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utility methods 
//////////////////////////////////////////////////////////////////////////////////////////////// 

- (void) changeCardinalDirectionColor:(UIColor*)color font:(UIFont*)font
{
    UILabel* label = nil;
    SGRadar* radar = arViewController.arView.radar;
    for(SGCardinalDirection direction = 0; direction < 4; direction++) {
        label = [radar labelForCardinalDirection:direction];
        label.font = font;
        label.textColor = color;
    }
}    

- (NSArray*) createLocationPointsBasedOnLocation:(CLLocation*)location amount:(NSInteger)amount
{
    NSMutableArray* locations = [NSMutableArray array];
    double latitude;
    double longitude;
    for(int i = 0; i < amount; i++) {
        latitude = ((rand() % 100) * 0.00001) * ((rand() % 2 ? -1.0 : 1.0)) + location.coordinate.latitude;
        longitude = ((rand() % 100) * 0.00001) * ((rand() % 2 ? -1.0 : 1.0)) + location.coordinate.longitude;
                
        [locations addObject:[[[CLLocation alloc] initWithLatitude:latitude
                                                             longitude:longitude] 
                                            autorelease]];
    }
    
    return locations;
}

- (void) resetAREnvironment
{
    SGARView* arView = arViewController.arView;

    arView.enableWalking = NO;
    arView.enableGridLines = NO;
    arView.radar.headingImageView.image = nil;
    arView.radar.currentLocationImageView.image = nil;
    arView.radar.shouldShowCardinalDirections = YES;
    arView.radar.radarBackgroundImageView.image = nil;
    [arView removeContainer:safeZone];
    
    glDisable(GL_LIGHTING);
    
    SGSetEnvironmentViewingRadius(100.0f);    
    SGSetEnvironmentMinimumAnnotationDistance(3.0);
    SGSetEnvironmentMaximumAnnotationDistance(100.0f);
    arNavigationController.toolbar.translucent = NO;
    
    [self changeCardinalDirectionColor:[UIColor whiteColor] font:[UIFont boldSystemFontOfSize:12.0]];
}

- (void) showMessage
{
    NSArray* containers = [arViewController.arView getContainers];
    
    BOOL showMessage = NO;
    for(SGAnnotationViewContainer* container in  containers)
        showMessage |= ![container isEmpty];
    
    if(showMessage) {
        
        // A little foreplay...
        NSString* title = rand() % 2 ? (rand() % 2 ? @"My Hero!": @"Dreams do come true!") : (rand() % 2 ? @"Praise be to Disney!" : @"I owe you one.");
        
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:@""
                                                           delegate:nil 
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];
    }
}

- (void) dealloc
{
    [arViewController release];
    [annotations release];
    [stylesTableView release];
    
    [super dealloc];
}

@end



//
//  MRSPatient.m
//  OpenMRS-iOS
//
//  Created by Parker Erway on 12/1/14.
//  
//

#import "MRSPatient.h"
#import <CoreData/CoreData.h>
#import "AppDelegate.h"
@implementation MRSPatient
- (void)saveToCoreData
{
    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    
    NSManagedObjectContext *managedContext = appDelegate.managedObjectContext;

    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Patient" inManagedObjectContext:managedContext];
    
    NSManagedObject *patient = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:managedContext];
    
    [patient setValue:[self valueNotNullAndIsString:self.UUID] forKey:@"uuid"];
    [patient setValue:[self valueNotNullAndIsString:self.address1] forKey:@"address1"];
    [patient setValue:[self valueNotNullAndIsString:self.address2] forKey:@"address2"];
    [patient setValue:[self valueNotNullAndIsString:self.address3] forKey:@"address3"];
    [patient setValue:[self valueNotNullAndIsString:self.address4] forKey:@"address4"];
    [patient setValue:[self valueNotNullAndIsString:self.address5] forKey:@"address5"];
    [patient setValue:[self valueNotNullAndIsString:self.address6] forKey:@"address6"];
    [patient setValue:[self valueNotNullAndIsString:self.age] forKey:@"age"];
    [patient setValue:[self valueNotNullAndIsString:self.birthdate] forKey:@"birthdate"];
//    [patient setValue:[self valueNotNullAndIsString:self.birthdateEstimated ] forKey:@"birthdateEstimated"];
    [patient setValue:[self valueNotNullAndIsString:self.causeOfDeath] forKey:@"causeOfDeath"];
    [patient setValue:[self valueNotNullAndIsString:self.cityVillage] forKey:@"cityVillage"];
    [patient setValue:[self valueNotNullAndIsString:self.country] forKey:@"country"];
    [patient setValue:[self valueNotNullAndIsString:self.countyDistrict] forKey:@"countyDistrict"];
    [patient setValue:[self valueNotNullAndIsString:self.deathDate] forKey:@"deathDate"];
    [patient setValue:[self valueNotNullAndIsString:self.display] forKey:@"display"];
    [patient setValue:[self valueNotNullAndIsString:self.displayName] forKey:@"displayName"];
    [patient setValue:[self valueNotNullAndIsString:self.endDate] forKey:@"endDate"];
    [patient setValue:[self valueNotNullAndIsString:self.familyName] forKey:@"familyName"];
    [patient setValue:[self valueNotNullAndIsString:self.familyName2] forKey:@"familyName2"];
    [patient setValue:[self valueNotNullAndIsString:self.gender] forKey:@"gender"];
    [patient setValue:[self valueNotNullAndIsString:self.givenName] forKey:@"givenName"];
    [patient setValue:[self valueNotNullAndIsString:[NSNumber numberWithBool:self.hasDetailedInfo]] forKey:@"hasDetailedInfo"];
    [patient setValue:[self valueNotNullAndIsString:self.latitude] forKey:@"latitude"];
    [patient setValue:[self valueNotNullAndIsString:self.locationDisplay] forKey:@"locationDisplay"];
    [patient setValue:[self valueNotNullAndIsString:self.longitude] forKey:@"longitude"];
    [patient setValue:[self valueNotNullAndIsString:self.middleName] forKey:@"middleName"];
    [patient setValue:[self valueNotNullAndIsString:self.name] forKey:@"name"];
    [patient setValue:[self valueNotNullAndIsString:self.postalCode] forKey:@"postalCode"];
    [patient setValue:[self valueNotNullAndIsString:self.stateProvince] forKey:@"stateProvince"];
    
    NSError *error;
    
    if (![managedContext save:&error])
    {
        NSLog(@"Error saving patient! %@", error);
    }
}
- (void)updateFromCoreData
{
    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    
    NSManagedObjectContext *managedContext = appDelegate.managedObjectContext;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Patient" inManagedObjectContext:appDelegate.managedObjectContext]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", self.UUID];
    [request setPredicate:predicate];
    
    NSError *error;
    
    NSArray *results = [managedContext executeFetchRequest:request error:&error];
    
    if (error)
    {
        NSLog(@"Error retrieving patient data from Core Data: %@", error);
    }
    else if (results.count > 1)
    {
        NSManagedObject *result = results[0];
        
        self.address1 = [result valueForKey:@"address1"];
        self.address2 = [result valueForKey:@"address2"];
        self.address3 = [result valueForKey:@"address3"];
        self.address4 = [result valueForKey:@"address4"];
        self.address5 = [result valueForKey:@"address5"];
        self.address6 = [result valueForKey:@"address6"];
        self.age = [result valueForKey:@"age"];
        self.birthdate = [result valueForKey:@"birthdate"];
        self.birthdateEstimated = [result valueForKey:@"birthdateEstimated"];
        self.causeOfDeath = [result valueForKey:@"causeOfDeath"];
        self.cityVillage = [result valueForKey:@"cityVillage"];
        self.country = [result valueForKey:@"country"];
        self.countyDistrict = [result valueForKey:@"countyDistrict"];
        self.deathDate = [result valueForKey:@"deathDate"];
        self.display = [result valueForKey:@"display"];
        self.displayName = [result valueForKey:@"displayName"];
        self.endDate = [result valueForKey:@"endDate"];
        self.familyName = [result valueForKey:@"familyName"];
        self.familyName2 = [result valueForKey:@"familyName2"];
        self.gender = [result valueForKey:@"gender"];
        self.givenName = [result valueForKey:@"givenName"];
        self.hasDetailedInfo = [[result valueForKey:@"hasDetailedInfo"] boolValue];
        self.latitude = [result valueForKey:@"latitude"];
        self.locationDisplay = [result valueForKey:@"locationDisplay"];
        self.longitude = [result valueForKey:@"longitude"];
        self.middleName = [result valueForKey:@"middleName"];
        self.name = [result valueForKey:@"name"];
        self.postalCode = [result valueForKey:@"postalCode"];
        self.stateProvince = [result valueForKey:@"stateProvince"];
        
        self.fromCoreData = YES;
    }
}
- (BOOL)isInCoreData
{
    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Patient" inManagedObjectContext:appDelegate.managedObjectContext]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", self.UUID];
    [request setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *results = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    NSLog(@"results count: %lu", (unsigned long)results.count);
    
    if (results.count > 0)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}
- (id)valueNotNullAndIsString:(id)value
{
    if (value == [NSNull null] || ![[value class] isSubclassOfClass:[NSString class]])
    {
        return nil;
    }
    return value;
}
@end

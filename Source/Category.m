/**
 * Copyright (c) 2007, 2012, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import "Category.h"
#import "BankStatement.h"
#import "MOAssistant.h"
#import "ShortDate.h"
#import "BankingController.h"
#import "StatCatAssignment.h"
#import "CategoryReportingNode.h"

#import "GraphicsAdditions.h"

static Category *catRootSingleton = nil;
static Category *bankRootSingleton = nil;
static Category *notAssignedRootSingleton = nil;

ShortDate *startReportDate = nil;
ShortDate *endReportDate = nil;

BOOL updateSent = NO;

// balance: sum of own statements
// catSum: sum of balance and child's catSums


@implementation Category

@dynamic rule;
@dynamic name;
@dynamic isBankAcc;
@dynamic currency;
@dynamic parent;
@dynamic isBalanceValid;
@dynamic catSum;
@dynamic balance;
@dynamic noCatRep;
@dynamic catRepColor;
@dynamic iconName;

@synthesize categoryColor;


-(void)updateInvalidBalances
{
    NSArray *stats;
    NSMutableSet* childs = [self mutableSetValueForKey: @"children" ];
    if([childs count ] > 0) {
        // first handle children
        NSEnumerator *enumerator = [childs objectEnumerator];
        Category	 *cat;
        
        while ((cat = [enumerator nextObject])) {
            [cat updateInvalidBalances ];
        }
    }
    // now handle self
    if([self.isBalanceValid boolValue ] == NO) {
        NSDecimalNumber	*balance = [NSDecimalNumber zero ];
        
        if ([self isBankAccount]) {
            stats = [[self mutableSetValueForKey: @"assignments"] allObjects];
        } else {
            //NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            assert(startReportDate != nil);
            assert(endReportDate != nil);
            stats = [self statementsFrom: startReportDate //[ShortDate dateWithDate: [defaults objectForKey: @"startReportDate"]]
                                      to: endReportDate //[ShortDate dateWithDate: [defaults objectForKey: @"endReportDate"]]
                            withChildren: NO];
        }
        
        StatCatAssignment *stat = nil;
        for(stat in stats) {
            balance = [balance decimalNumberByAdding: stat.value ];
        }
        if(stat) {
            NSString *curr = stat.statement.currency;
            if(curr != nil && [curr length ] > 0) self.currency = curr;
        }
        self.balance = balance;
        self.isBalanceValid = [NSNumber numberWithBool: YES ];
    }
}

-(void)rebuildValues
{
    NSArray *stats;
    NSMutableSet* childs = [self mutableSetValueForKey: @"children" ];
    if([childs count ] > 0) {
        // first handle children
        NSEnumerator *enumerator = [childs objectEnumerator];
        Category	 *cat;
        
        while ((cat = [enumerator nextObject])) {
            [cat rebuildValues ];
        }
    }
    // now handle self
    NSDecimalNumber	*balance = [NSDecimalNumber zero ];
    
    if ([self isBankAccount]) {
        stats = [[self mutableSetValueForKey: @"assignments"] allObjects];
    }
    else {
        //NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        assert(startReportDate != nil);
        assert(endReportDate != nil);
        stats = [self statementsFrom: startReportDate //[ShortDate dateWithDate: [defaults objectForKey: @"startReportDate"]]
                                  to: endReportDate //[ShortDate dateWithDate: [defaults objectForKey: @"endReportDate"]]
                        withChildren: NO];
    }
    
    for(StatCatAssignment *stat in stats) {
        if(stat.value != nil) balance = [balance decimalNumberByAdding: stat.value]; else stat.value = [NSDecimalNumber zero ];
    }
    self.balance = balance;
}

-(NSMutableSet*)combinedStatements
{
    if(![self isBankAccount ]) return [self mutableSetValueForKey: @"assignments" ];
    if(self.accountNumber) return [self mutableSetValueForKey: @"assignments" ];
    // combine statements
    NSMutableSet *stats = [[NSMutableSet alloc ] init ];
    NSSet *childs = [self allChildren ];
    NSEnumerator *enumerator = [childs objectEnumerator];
    Category *cat;
    while ((cat = [enumerator nextObject]) != nil) {
        [stats unionSet: [cat mutableSetValueForKey: @"assignments"]];
    }
    return stats;
}

-(NSDecimalNumber*)rollup
{
    NSDecimalNumber *res;
    Category		*cat, *cat_old = nil;
    
    NSMutableSet* childs = [self mutableSetValueForKey: @"children" ];
    NSEnumerator *enumerator = [childs objectEnumerator];
    res = self.balance;
    while ((cat = [enumerator nextObject])) { res = [res decimalNumberByAdding: [cat rollup ] ]; cat_old = cat; }
    self.catSum = res;
    if(cat_old) {
        NSString *curr = cat_old.currency;
        if(curr != nil && [curr length ] > 0) self.currency = curr;
    }
    // reset update flag
    updateSent = NO;
    return res;
}

-(void)invalidateBalance
{
    self.isBalanceValid = [NSNumber numberWithBool: NO ];
}


-(NSDecimalNumber*)valuesOfType: (CatValueType)type from: (ShortDate*)fromDate to: (ShortDate*)toDate
{
    NSDecimalNumber* result = [NSDecimalNumber zero];
    NSMutableSet* stats = [self mutableSetValueForKey: @"assignments"];
    NSMutableSet* childs = [self mutableSetValueForKey: @"children"];
    
    if ([childs count] > 0)
    {
        // first handle children
        NSEnumerator *enumerator = [childs objectEnumerator];
        Category	 *cat;
        
        while ((cat = [enumerator nextObject])) {
            result = [result decimalNumberByAdding: [cat valuesOfType: type from: fromDate to: toDate]];
        }
    }
    
    if ([stats count] > 0)
    {
        NSDecimalNumber* zero = [NSDecimalNumber zero];
        NSEnumerator* enumerator = [stats objectEnumerator];
        StatCatAssignment* stat;
        
        switch (type)
        {
            case cat_all:
                while ((stat = [enumerator nextObject]))
                {
                    ShortDate* date = [ShortDate dateWithDate: stat.statement.date];
                    if ([date isBetween: fromDate and: toDate])
                        result = [result decimalNumberByAdding: stat.value];
                }
                break;
            case cat_earnings:
                while ((stat = [enumerator nextObject]))
                {
                    ShortDate* date = [ShortDate dateWithDate: stat.statement.date];
                    if ([date isBetween: fromDate and: toDate] && ([stat.value compare: zero] == NSOrderedDescending))
                        result = [result decimalNumberByAdding: stat.value];
                }
                break;
            case cat_spendings:
                while ((stat = [enumerator nextObject]))
                {
                    ShortDate* date = [ShortDate dateWithDate: stat.statement.date];
                    if ([date isBetween: fromDate and: toDate] && ([stat.value compare: zero] == NSOrderedAscending))
                        result = [result decimalNumberByAdding: stat.value];
                }
                break;
            case cat_turnovers:
            {
                int turnovers = 0;
                while ((stat = [enumerator nextObject]))
                {
                    ShortDate* date = [ShortDate dateWithDate: stat.statement.date];
                    if ([date isBetween: fromDate and: toDate])
                        turnovers++;
                }
                result = [result decimalNumberByAdding: [NSDecimalNumber decimalNumberWithMantissa: turnovers
                                                                                          exponent: 0
                                                                                        isNegative: NO]];
                break;
            }
        }
    }
    return result;
}

-(NSArray*)statementsFrom: (ShortDate*)fromDate to: (ShortDate*)toDate withChildren: (BOOL)c
{
    NSMutableArray	*result = [NSMutableArray arrayWithCapacity: 100 ];
    
    NSMutableSet* stats = [self mutableSetValueForKey: @"assignments" ];
    NSMutableSet* childs = [self mutableSetValueForKey: @"children" ];
    
    if(c == YES && [childs count ] > 0) {
        // first handle children
        NSEnumerator *enumerator = [childs objectEnumerator];
        Category	 *cat;
        
        while ((cat = [enumerator nextObject])) {
            [result addObjectsFromArray: [cat statementsFrom: fromDate to: toDate withChildren: YES ] ];
        }
    }
    
    if([stats count ] > 0) {
        NSEnumerator *enumerator = [stats objectEnumerator ];
        StatCatAssignment *stat;
        while ((stat = [enumerator nextObject])) {
            ShortDate *date = [ShortDate dateWithDate: stat.statement.date ];
            if(![date isBetween: fromDate and: toDate ]) continue;
            [result addObject: stat ];
        }
    }
    return result;	
}


-(NSString*)accountNumber { return nil; }

-(NSString*)localName
{
    [self willAccessValueForKey:@"name"];
    NSString *n = [self primitiveValueForKey:@"name"];
    [self didAccessValueForKey:@"name"];
    if(self.parent == nil) {
        if([n isEqualToString: @"++bankroot" ]) return NSLocalizedString(@"banking_root", @"");
        if([n isEqualToString: @"++catroot" ]) return NSLocalizedString(@"category_root", @"");
    }
    if([n isEqualToString: @"++nassroot" ]) return NSLocalizedString(@"nass_root", @"");
    return n;
}

/**
 * Sets the name of this category to the given value. Checks are done to ensure that the overall
 * structure will not be broken.
 */
-(void)setLocalName: (NSString*)name
{
    if (name == nil)
        return;
    
    [self willAccessValueForKey: @"name"];
    NSString *n = [self primitiveValueForKey: @"name"];
    [self didAccessValueForKey: @"name"];
    
    // Check for special node names denoting certain built-in elements and refuse to rename them.
    if (n != nil)
    {
        // The existing name must have a value for this check to work properly.
        NSRange r = [n rangeOfString: @"++"];
        if (r.location == 0)
            return;
    }
    
    // Check also the new name so it doesn't use our special syntax to denote such elements.
    NSRange r = [name rangeOfString: @"++"];
    if (r.location == 0)
        return;
    
    [self setValue: name forKey: @"name"];
}

-(BOOL)isRoot
{
    return self.parent == nil;
}

-(BOOL)isBankAccount
{
    return [self.isBankAcc boolValue ];
}

-(BOOL)isBankingRoot
{
    if( self.parent == nil ) return [self.isBankAcc boolValue ];
    return NO;
}

-(BOOL)isEditable
{
    if(self.parent == nil) return NO;
    NSString *n = [self primitiveValueForKey:@"name"];
    if(n != nil) {
        NSRange r = [n rangeOfString: @"++" ];
        if(r.location == 0) return NO;
    }
    return YES;
    //	return [self isMemberOfClass: [Category class ] ];
}

-(BOOL)isRemoveable
{
    if(self.parent == nil) return NO;
    NSString *n = [self primitiveValueForKey:@"name"];
    if(n != nil) {
        NSRange r = [n rangeOfString: @"++" ];
        if(r.location == 0) return NO;
    }
    NSSet* myChildren = [self mutableSetValueForKey: @"children" ];
    if([myChildren count ] > 0) return NO;
    return [self isMemberOfClass: [Category class ] ];
}

-(BOOL)isInsertable
{
    if( [self.isBankAcc boolValue ] == YES) return NO;
    //	if( [self valueForKey: @"parent" ] == nil ) return NO;
    NSString *n = [self primitiveValueForKey:@"name"];
    if([n isEqual: @"++nassroot" ]) return NO;
    return TRUE;
}

-(BOOL)isRequestable
{
    if(![self isBankAccount ]) return NO;
    if([[BankingController controller ] requestRunning ]) return NO; else return YES;
}

-(BOOL)isNotAssignedCategory
{
    return self == [Category nassRoot ];
}

-(NSMutableSet*)children
{
    return [self mutableSetValueForKey: @"children" ];
}


-(NSSet*)allChildren
{
    NSMutableSet* childs = [[NSMutableSet alloc ] init ];
    
    NSSet* myChildren = [self children ];
    NSEnumerator *enumerator = [myChildren objectEnumerator];
    Category	 *cx;
    
    while ((cx = [enumerator nextObject])) {
        NSSet* sub = [cx allChildren ];
        [childs unionSet: sub ];
    }
    [childs addObject: self ];
    return childs;
}

-(NSSet*)siblings
{
    Category* parent = self.parent;
    if(parent == nil) return nil;
    NSMutableSet* set = [NSMutableSet setWithSet: [parent mutableSetValueForKey: @"children" ] ];
    [set removeObject: self ];
    return set;
}

/**
 * Collects a history of the saldo movement for this category over time.
 * This is usually only meaningful for bank accounts.
 * The resulting arrays are sorted by ascending date.
 */
-(NSUInteger)balanceHistoryToDates: (NSArray**)dates
                          balances: (NSArray**)balances
                     balanceCounts: (NSArray**)counts
                      withGrouping: (GroupingInterval)interval
{
    NSArray* stats = [[self mutableSetValueForKey: @"assignments"] allObjects];
    NSArray* sortedStats = [stats sortedArrayUsingSelector: @selector(compareDate:)];
    
    NSUInteger count = [stats count];
    NSMutableArray* dateArray = [NSMutableArray arrayWithCapacity: count];
    NSMutableArray* balanceArray = [NSMutableArray arrayWithCapacity: count];
    NSMutableArray* countArray = [NSMutableArray arrayWithCapacity: count];
    if (count > 0)
    {
        ShortDate* lastDate = nil;
        int balanceCount = 1;
        NSDecimalNumber* lastSaldo = nil;
        for (NSUInteger i = 0; i < [stats count]; i++) {
            StatCatAssignment* assignment = [sortedStats objectAtIndex: i];
            ShortDate* date = [ShortDate dateWithDate: assignment.statement.date];
            
            switch (interval) {
                case GroupByWeeks:
                    date = [date firstDayInWeek];
                    break;
                case GroupByMonths:
                    date = [date firstDayInMonth];
                    break;
                case GroupByQuarters:
                    date = [date firstDayInQuarter];
                    break;
                case GroupByYears:
                    date = [date firstDayInYear];
                    break;
                default:
                    break;
            }            

            if (lastDate == nil) {
                lastDate = date;
            } else {
                if ([lastDate compare: date] != NSOrderedSame)
                {
                    [dateArray addObject: lastDate];
                    [balanceArray addObject: lastSaldo];
                    [countArray addObject: [NSNumber numberWithInt: balanceCount]];
                    balanceCount = 1;
                    lastDate = date;
                }
                else
                {
                    balanceCount++;
                }
            }                
            lastSaldo = assignment.statement.saldo;
        }
        if (lastDate != nil) {
            [dateArray addObject: lastDate];
            [balanceArray addObject: lastSaldo];
            [countArray addObject: [NSNumber numberWithInt: balanceCount]];
        }            
        *dates = dateArray;
        *balances = balanceArray;
        *counts = countArray;
    }
    
    return count;
}

/**
 * Returns the dates of the oldest and newest entry for this category and all its children.
 */
- (void)getDatesMin: (ShortDate **)minDate max: (ShortDate **)maxDate
{
    ShortDate* currentMinDate = [ShortDate currentDate];
    ShortDate* currentMaxDate = [ShortDate currentDate];
    
    // First get the dates from all child categories and then compare them to dates of this one.
    NSMutableSet* children = [self mutableSetValueForKey: @"children" ];
    for (Category* category in children) {
        ShortDate *localMin, *localMax;
        [category getDatesMin: &localMin max: &localMax];
        if ([localMin compare: currentMinDate] == NSOrderedAscending) {
            currentMinDate = localMin;
        }
        if ([localMax compare: currentMaxDate] == NSOrderedDescending) {
            currentMaxDate = localMax;
        }
    }
    
    NSArray* stats = [[self mutableSetValueForKey: @"assignments"] allObjects];
    NSArray* sortedStats = [stats sortedArrayUsingSelector: @selector(compareDate:)];
    
    if ([sortedStats count] > 0) {
        StatCatAssignment* assignment = [sortedStats objectAtIndex: 0];
        ShortDate* date = [ShortDate dateWithDate: assignment.statement.date];
        if ([date compare: currentMinDate] == NSOrderedAscending) {
            currentMinDate = date;
        }
        assignment = [sortedStats lastObject];
        date = [ShortDate dateWithDate: assignment.statement.date];
        if ([date compare: currentMaxDate] == NSOrderedDescending) {
            currentMaxDate = date;
        }
    }
    *minDate = currentMinDate;
    *maxDate = currentMaxDate;
}

/**
 * Returns a list of all statements for this category, including sub categories.
 */
-(NSSet*)allStatements
{
    NSMutableSet* result = [NSMutableSet setWithSet: [self mutableSetValueForKey: @"assignments" ]];
    NSMutableSet* childs = [self mutableSetValueForKey: @"children" ];
    
    if ([childs count] > 0)
    {
        NSEnumerator* enumerator = [childs objectEnumerator];
        Category* child;
        
        while ((child = [enumerator nextObject]))
        {
            [result unionSet: [child allStatements]];
        }
    }
    
    return result;	
}


/**
 * Collects a full history of turnover values over time, including all sub categories.
 */
-(NSUInteger)categoryHistoryToDates: (NSArray**)dates
                           balances: (NSArray**)balances
                      balanceCounts: (NSArray**)counts
                       withGrouping: (GroupingInterval)interval
{
    NSArray* stats = [[self allStatements] allObjects];
    NSArray* sortedStats = [stats sortedArrayUsingSelector: @selector(compareDate:)];
    
    NSUInteger count = [stats count];
    NSMutableArray* dateArray = [NSMutableArray arrayWithCapacity: count];
    NSMutableArray* balanceArray = [NSMutableArray arrayWithCapacity: count];
    NSMutableArray* countArray = [NSMutableArray arrayWithCapacity: count];
    if (count > 0)
    {
        ShortDate* lastDate = nil;
        int balanceCount = 0;
        NSDecimalNumber* currentValue = [NSDecimalNumber zero];
        for (StatCatAssignment* assignment in sortedStats) {
            ShortDate* date = [ShortDate dateWithDate: assignment.statement.date];
            
            switch (interval) {
                case GroupByWeeks:
                    date = [date firstDayInWeek];
                    break;
                case GroupByMonths:
                    date = [date firstDayInMonth];
                    break;
                case GroupByQuarters:
                    date = [date firstDayInQuarter];
                    break;
                case GroupByYears:
                    date = [date firstDayInYear];
                    break;
                default:
                    break;
            }            

            if ((lastDate != nil) && [lastDate compare: date] != NSOrderedSame)
            {
                [dateArray addObject: lastDate];
                [balanceArray addObject: currentValue];
                [countArray addObject: [NSNumber numberWithInt: balanceCount]];
                balanceCount = 1;
                lastDate = date;
                currentValue = assignment.statement.value;
            }
            else
            {
                if (lastDate == nil) {
                    lastDate = date;
                }
                balanceCount++;
                currentValue = [currentValue decimalNumberByAdding: assignment.statement.value];
            }
        }
        [dateArray addObject: lastDate];
        [balanceArray addObject: currentValue];
        [countArray addObject: [NSNumber numberWithInt: balanceCount]];
        
        *dates = dateArray;
        *balances = balanceArray;
        *counts = countArray;
    }
    
    return count;
}

-(BOOL)checkMoveToCategory:(Category*)cat
{
    Category *parent;
    if ([cat isBankAccount]) return NO;
    if (cat == notAssignedRootSingleton) return NO;
    
    // check for cycles
    parent = cat.parent;
    while (parent != nil) {
        if (parent == self) return NO;
        parent = parent.parent;
    }
    return YES;
}

-(NSColor*)categoryColor
{
    // Assign a default color if none has been set so far.
    // Root categories get different dark gray default colors. Others either get one of the predefined
    // colors or a random one if no color is left from the set of predefined colors.
    [self willAccessValueForKey: @"categoryColor"];
    if (self.catRepColor == nil) {
        if (self == [Category bankRoot]) {
            catColor = [NSColor colorWithDeviceWhite: 0.12 alpha: 1];
        } else {
            if (self == [Category catRoot]) {
                catColor = [NSColor colorWithDeviceWhite: 0.24 alpha: 1];
            } else {
                if (self == [Category nassRoot]) {
                    catColor = [NSColor colorWithDeviceWhite: 0.36 alpha: 1];
                } else {
                    if ([self isBankAccount]) {
                        catColor = [NSColor nextDefaultAccountColor];
                    } else {
                        catColor = [NSColor nextDefaultCategoryColor];
                    }
                }
            }
        }
        
        // Archive the just determined color.
        NSMutableData* data = [NSMutableData data];

        NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData: data];
        [archiver encodeObject: catColor forKey: @"color"];
        [archiver finishEncoding];
        
        self.catRepColor = data;
    } else {
        if (catColor == nil) {
            NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData: self.catRepColor];
            catColor = [unarchiver decodeObjectForKey: @"color"];
            [unarchiver finishDecoding];
        }
    }

    [self didAccessValueForKey: @"categoryColor"];

    return catColor;
}

-(void)setCategoryColor: (NSColor*)color
{
    if (catColor != color) {
        [self willChangeValueForKey: @"categoryColor"];
        catColor = color;
        
        NSMutableData* data = [NSMutableData data];
        
        NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData: data];
        [archiver encodeObject: catColor forKey: @"color"];
        [archiver finishEncoding];
        
        self.catRepColor = data;
        [self didChangeValueForKey: @"categoryColor"];
    }
}

+(Category*)bankRoot
{
    NSError *error = nil;
    if(bankRootSingleton) return bankRootSingleton;
    
    NSManagedObjectContext	*context = [[MOAssistant assistant ] context ];
    NSManagedObjectModel	*model   = [[MOAssistant assistant ] model ];
    
    NSFetchRequest *request = [model fetchRequestTemplateForName:@"getBankingRoot"];
    NSArray *cats = [context executeFetchRequest:request error:&error];
    if( error != nil || cats == nil) {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return nil;
    }
    if([cats count ] > 0) return [cats objectAtIndex: 0 ];
    
    // create Root object
    bankRootSingleton = [NSEntityDescription insertNewObjectForEntityForName:@"Category" inManagedObjectContext:context];
    [bankRootSingleton setValue: @"++bankroot" forKey: @"name" ];
    [bankRootSingleton setValue: [NSNumber numberWithBool: YES ] forKey: @"isBankAcc" ];
    return bankRootSingleton;
}


+(Category*)catRoot
{
    NSError *error = nil;
    if(catRootSingleton) return catRootSingleton;
    
    NSManagedObjectContext	*context = [[MOAssistant assistant ] context ];
    NSManagedObjectModel	*model   = [[MOAssistant assistant ] model ];
    
    if (context == nil) return nil;
    NSFetchRequest *request = [model fetchRequestTemplateForName:@"getCategoryRoot"];
    NSArray *cats = [context executeFetchRequest:request error:&error];
    if( error != nil || cats == nil) {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return nil;
    }
    if([cats count ] > 0) return [cats objectAtIndex: 0 ];
    
    // create Category Root object
    catRootSingleton = [NSEntityDescription insertNewObjectForEntityForName:@"Category" inManagedObjectContext:context];
    [catRootSingleton setValue: @"++catroot" forKey: @"name" ];
    [catRootSingleton setValue: [NSNumber numberWithBool: NO ] forKey: @"isBankAcc" ];
    return catRootSingleton;
}

+(Category*)nassRoot
{
    NSError *error = nil;
    if(notAssignedRootSingleton) return notAssignedRootSingleton;
    
    NSManagedObjectContext	*context = [[MOAssistant assistant ] context];
    NSManagedObjectModel	*model   = [[MOAssistant assistant ] model];
    
    NSFetchRequest *request = [model fetchRequestTemplateForName: @"getNassRoot"];
    NSArray *cats = [context executeFetchRequest: request error: &error];
    if( error != nil || cats == nil) {
        return nil;
    }

    if ([cats count ] > 0) {
        notAssignedRootSingleton = [cats objectAtIndex: 0];
    } else {
        Category *notAssignedRootSingleton = [NSEntityDescription insertNewObjectForEntityForName: @"Category"
                                                                           inManagedObjectContext: context];
        [notAssignedRootSingleton setPrimitiveValue: @"++nassroot" forKey: @"name"];
        [notAssignedRootSingleton setValue: [NSNumber numberWithBool: NO] forKey: @"isBankAcc"];
        [notAssignedRootSingleton setValue: catRootSingleton forKey: @"parent"];
    }

    return notAssignedRootSingleton;
}

+(void)updateCatValues
{
    if (updateSent) return;
    [[self catRoot ] updateInvalidBalances ];
    [[self catRoot ] rollup ]; 
}

+(void)setCatReportFrom: (ShortDate*)fDate to: (ShortDate*)tDate
{
    if (startReportDate != nil && endReportDate != nil) {
        if ([startReportDate isEqual:fDate] && [endReportDate isEqual:tDate]) {
            return;
        }
    }
    
    startReportDate = fDate;
    endReportDate = tDate;
    [[self catRoot ] rebuildValues ];
    [[self catRoot ] rollup ];

    /*
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: fDate.lowDate forKey: @"startReportDate"];
    [defaults setObject: tDate.lowDate forKey: @"endReportDate"];
    */
}

/**
 * Recreate the 3 implicit root categories. Called when the entire managed context was cleared.
 */
+ (void)recreateRoots
{
    catRootSingleton = nil, [self catRoot];
    bankRootSingleton = nil, [self bankRoot];
    notAssignedRootSingleton = nil, [self nassRoot];
}

/**
 * Creates a set of default categories, which are quite common. These categories are defined in localizable.strings.
 */
+ (void)createDefaultCategories
{
    NSString *sentinel = NSLocalizedString(@"AP300", nil); // Upper limit.
    if (sentinel == nil || sentinel.length == 0) {
        return;
    }

    NSUInteger lower = 250;
    NSUInteger upper = [sentinel intValue];
    if (upper <= lower) {
        return;
    }

    NSUInteger lastLevel = 0;
    NSManagedObjectContext *context = MOAssistant.assistant.context;
    Category *current = [Category nassRoot];

    for (NSUInteger i = lower; i <= upper; i++) {
        NSString *key = [NSString stringWithFormat: @"AP%lu", i];
        NSString *name = NSLocalizedString(key, nil);

        // Count leading plus chars (they determine the nesting level) and remove them.
        NSUInteger level = 0;
        while ([name characterAtIndex: level] == '+') {
            level++;
        }
        if (level > 0) {
            name = [name substringFromIndex: level];
        }

        Category *child = [NSEntityDescription insertNewObjectForEntityForName: @"Category" inManagedObjectContext: context];
        child.name = name;
        if (level < lastLevel) {
            // Go up the parent chain as many levels as indicated.
            while (lastLevel > level) {
                current = current.parent;
                lastLevel--;
            }
            child.parent = current.parent;
        } else {
            if (level > lastLevel) {
                // Go down one level (there must never be level increases with more than one step).
                child.parent = current;
                lastLevel++;
            } else {
                // Add new sibling to the current node.
                child.parent = current.parent;
            }
        }
        current = child;
    }

    // TODO: add rules to each category

    NSError *error;
    if (![context save: &error]) {
        NSAlert *alert = [NSAlert alertWithError: error];
        [alert runModal];
        return;
    }
}
@end
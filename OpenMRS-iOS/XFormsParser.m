//
//  XFormsParser.m
//  OpenMRS-iOS
//
//  Created by Yousef Hamza on 7/20/15.
//  Copyright (c) 2015 Erway Software. All rights reserved.
//

#import "XFormsParser.h"
#import "XForms.h"
#import "GDataXMLNode.h"
#import "XFormElement.h"
#import "Constants.h"
#import "SimpleAudioViewController.h"
#import "MapViewController.h"
#import "CLLocationValueTrasformer.h"
#import "MRSDateUtilities.h"
#import "MRSPatient.h"
#import "MRSHelperFunctions.h"
#import <MapKit/MapKit.h>
#import <XLForm.h>

@implementation XFormsParser

+ (XForms *)parseXFormsXML:(GDataXMLDocument *)doc withID:(NSString *)formID andName:(NSString *)name Patient:(MRSPatient *)patient {
    XForms *form = [[XForms alloc] init];
    form.name = name;
    form.doc = doc;
    form.XFormsID = formID;
    form.forms = [[NSMutableArray alloc] init];
    form.groups = [[NSMutableArray alloc] init];
    
    GDataXMLElement *model = [doc.rootElement elementsForName:@"xf:model"][0];
    GDataXMLElement *instance = [model elementsForName:@"xf:instance"][0];
    GDataXMLElement *formNode = [instance elementsForName:@"form"][0];

    if ([formNode elementsForName:@"patient"].count > 0 && patient != nil) {
        NSLog(@"It's for patient!%@", patient.birthdateEstimated);
        form.isForPatient = YES;
        [XFormsParser fillFormDataTo:[formNode elementsForName:@"patient"][0] fromPatient:patient];
    }

    NSArray *bindings = [model elementsForName:@"xf:bind"];

    for (GDataXMLElement *group in [doc.rootElement elementsForName:@"xf:group"]) {
        [XFormsParser parseGroup:group toForm:form bindings:bindings instance:instance doc:doc];
    }
    return form;
}

+ (void)fillFormDataTo:(GDataXMLElement *)patientNode fromPatient:(MRSPatient *)patient {
    NSDictionary *attributeDict = [Constants PATIENT_ATTRIBUTES];
    NSDictionary *attributeTypeDict = [Constants PATIENT_ATTRIBUTES_TYPES];
    for (GDataXMLElement *patientElement in [patientNode children]) {
        NSLog(@"element :%@", patientElement.name);
        /* If key not recognized continue */
        if (![attributeDict objectForKey:patientElement.name]) {
            continue;
        }
        id value = [patient valueForKey:attributeDict[patientElement.name]];
        NSLog(@"key: %@, value:%@", attributeDict[patientElement.name], value);
        if ([MRSHelperFunctions isNull:value]) {
            continue;
        }

        if ([[Constants PATIENT_ATTRIBUTES_TYPES][patientElement.name] isEqualToString:kXFormsString]) {

            patientElement.stringValue = [patient valueForKey:attributeDict[patientElement.name]];
            if ([patientElement.name isEqualToString:@"patient.patient_id"]) {
                NSString *display = [patient valueForKey:attributeDict[patientElement.name]];
                patientElement.stringValue = @"4";
            }
        } else if ([attributeTypeDict[patientElement.name] isEqualToString:kXFormsDate]) {
            
            NSDate *date = [MRSDateUtilities dateFromOpenMRSFormattedString:[patient valueForKey:attributeDict[patientElement.name]]];
            
            patientElement.stringValue = [MRSDateUtilities XFormformatStringwithDate:date type:kXFormsDate];
        } else if ([attributeTypeDict[patientElement.name] isEqualToString:kXFormsBoolean]) {

            /* Only birthdate estimate for now, and it's set to "true" and "false" so no need to change that*/
            patientElement.stringValue = [patient valueForKey:attributeDict[patientElement.name]];
        }
    }
}

+ (void)parseGroup:(GDataXMLElement *)group toForm:(XForms *)form bindings:(NSArray *)bindings instance:(GDataXMLElement *)instance doc:(GDataXMLDocument *)doc {
    XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
    NSString *groupLabel = @"";
    
    //labels and hints
    if ([group elementsForName:@"xf:label"]) {
        groupLabel = [(GDataXMLElement *)([group elementsForName:@"xf:label"][0]) stringValue];
    }
    if ([group elementsForName:@"xf:hint"]) {
        section.title = [(GDataXMLElement *)([group elementsForName:@"xf:hint"][0]) stringValue];
    }
    XLFormDescriptor *formDescriptor = [XLFormDescriptor formDescriptorWithTitle:groupLabel];
    NSMutableDictionary *groupDict = [[NSMutableDictionary alloc] init];
    BOOL isWizard = [[NSUserDefaults standardUserDefaults] boolForKey:@"isWizard"];
    if (!isWizard) {
        [formDescriptor addFormSection:section];
        [form.forms addObject:formDescriptor];
        [form.groups addObject:groupDict];
    }
    for (GDataXMLElement *element in [group children]) {
        //handling input
        if ([element.localName isEqualToString:@"input"] ||
            [element.localName isEqualToString:kXFormsSelect] ||
            [element.localName isEqualToString:kXFormsMutlipleSelect] ||
            [element.localName isEqualToString:kXFormsUpload]) {
            [XFormsParser parseInput:element bindings:bindings instance:instance Section:section Group:groupDict Document:doc];
        }
        //handling repeat
        if ([element.localName isEqualToString:kXFormsRepeat]) {
            [XFormsParser parseRepeat:element bindings:bindings instance:instance Section:section Group:groupDict Form:form Document:doc];
        }
        // handling group
        if ([element.localName isEqualToString:kXFormsGroup]) {
            [XFormsParser parseGroup:element toForm:form bindings:bindings instance:instance doc:doc];
        }
        if (isWizard) {
            if (section.formRows.count > 0) {
                if (section.formRows.count == 1 ||
                    (section.formRows.count == 2 && [[(XLFormRowDescriptor *)(section.formRows[0]) tag] isEqualToString:@"info"])) {
                    XLFormRowDescriptor *rowInSection = section.formRows[0];
                    if ([rowInSection.tag isEqualToString:@"info"]) {
                        rowInSection = section.formRows[1];
                    }
                    section.title = rowInSection.title;
                    rowInSection.title = @"";

                    
                    if (rowInSection.isDisabled) {
                        section.title = [NSString stringWithFormat:@"%@ (%@)", section.title, NSLocalizedString(@"Locked", @"Label locked")];
                    }
                    if (rowInSection.isRequired) {
                        NSAttributedString *requiredLabel = [[NSAttributedString alloc] initWithString:@""];
                        [rowInSection.cellConfig setObject:requiredLabel forKey:@"textLabel.attributedText"];

                        section.title = [NSString stringWithFormat:@"%@ (%@)", section.title, NSLocalizedString(@"Required", @"Label required")];
                    }
                }
                [formDescriptor addFormSection:section];
                [form.forms addObject:formDescriptor];
                [form.groups addObject:groupDict];
                /* Re-initializing */
                groupDict = [[NSMutableDictionary alloc] init];
                formDescriptor = [XLFormDescriptor formDescriptorWithTitle:groupLabel];
                section = [XLFormSectionDescriptor formSection];
            }
            
        }
    }
}

+ (void)parseRepeat:(GDataXMLElement *)repeat bindings:(NSArray *)bindings instance:(GDataXMLElement* )instance Section:(XLFormSectionDescriptor *)section Group:(NSMutableDictionary *)group Form:(XForms *)form Document:(GDataXMLDocument *)doc {
    XFormElement *formElement = [[XFormElement alloc] init];
    formElement.type = kXFormsRepeat;
    
    //labels and hints
    if ([repeat elementsForName:@"xf:label"]) {
        formElement.label = [(GDataXMLElement *)([repeat elementsForName:@"xf:label"][0]) stringValue];
        section.title = formElement.label;
    }
    if ([repeat elementsForName:@"xf:hint"]) {
        formElement.hint = [(GDataXMLElement *)([repeat elementsForName:@"xf:hint"][0]) stringValue];
        section.footerTitle = formElement.hint;
    }
    
    //bind ID -- used also as a tag for the row in the view.
    formElement.bindID = [(GDataXMLElement *)[repeat attributeForName:@"bind"] stringValue];
    GDataXMLElement *bindingForInput;
    for (GDataXMLElement *element in bindings) {
        if ([[[element attributeForName:@"id"] stringValue] isEqualToString:formElement.bindID]) {
            bindingForInput = element;
            break;
        }
    }

    //XMLNode
    NSString *nodeXPath = [[bindingForInput attributeForName:@"nodeset"] stringValue];
    GDataXMLElement *instanceNode = [instance nodesForXPath:[NSString stringWithFormat:@"/%@", nodeXPath] error:nil][0];
    formElement.XPathNode = nodeXPath;
    formElement.XMLnode = instanceNode;
    
    //Sub elements
    formElement.subElements = [[NSMutableDictionary alloc] init];
    for (GDataXMLElement *element in [repeat children]) {
        if ([element.localName isEqualToString:@"input"] ||
            [element.localName isEqualToString:kXFormsSelect] ||
            [element.localName isEqualToString:kXFormsMutlipleSelect] ||
            [element.localName isEqualToString:kXFormsUpload]) {
            //It adds the new row to the new section
            [XFormsParser parseInput:element bindings:bindings instance:instance Section:section Group:formElement.subElements Document:doc];
        }
    }
    [group setObject:formElement forKey:formElement.bindID];
}

+ (void)parseInput:(GDataXMLElement *)input bindings:(NSArray *)bindings instance:(GDataXMLElement* )instance Section:(XLFormSectionDescriptor *)section Group:(NSMutableDictionary *)group Document:(GDataXMLDocument *)doc {
    XFormElement *formElement = [[XFormElement alloc] init];
    //labels and hints
    if ([input elementsForName:@"xf:label"]) {
        formElement.label = [(GDataXMLElement *)([input elementsForName:@"xf:label"][0]) stringValue];
    }
    if ([input elementsForName:@"xf:hint"]) {
        formElement.hint = [(GDataXMLElement *)([input elementsForName:@"xf:hint"][0]) stringValue];
    }
    
    //bind ID -- used also as a tag for the row in the view.
    formElement.bindID = [(GDataXMLElement *)[input attributeForName:@"bind"] stringValue];
    GDataXMLElement *bindingForInput;
    for (GDataXMLElement *element in bindings) {
        if ([[[element attributeForName:@"id"] stringValue] isEqualToString:formElement.bindID]) {
            bindingForInput = element;
            break;
        }
    }
    
    //Type
    if ([[[bindingForInput attributeForName:@"type"] stringValue] isEqualToString:kXFormsString]) {
        if ([bindingForInput attributeForName:@"format"]) {
            formElement.type = kXFormsGPS;
        } else if ([input.localName isEqualToString:@"select1"]) {
            formElement.type = kXFormsSelect;
        } else if ([input.localName isEqualToString:@"select"]) {
            formElement.type = kXFormsMutlipleSelect;
        }else {
            formElement.type = kXFormsString;
        }
        
    } else if ([[[bindingForInput attributeForName:@"type"] stringValue] isEqualToString:kXFormBase64]) {
        if ([[[bindingForInput attributeForName:@"format"] stringValue] isEqualToString:kXFormsAudio]) {
            formElement.type = kXFormsAudio;
        } else if ([[[bindingForInput attributeForName:@"format"] stringValue] isEqualToString:kXFormsImage]) {
            formElement.type = kXFormsImage;
        }
    } else {
        formElement.type = [[bindingForInput attributeForName:@"type"] stringValue];
    }
    /* Sufficent data here to create the row */

    XLFormRowDescriptor *row = nil;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"isWizard"]) {
        if ([formElement.type isEqualToString:kXFormsBoolean]) {
            row = [XLFormRowDescriptor formRowDescriptorWithTag:formElement.bindID
                                                        rowType:XLFormRowDescriptorTypePicker
                                                          title:formElement.label];
        }
        row.selectorOptions = @[@"Yes", @"No"];
    }
    if (!row) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:formElement.bindID
                                                                         rowType:[[Constants MAPPING_TYPES] objectForKey:formElement.type]
                                                                           title:formElement.label];
    }
    
    /* Other elements than these handles alighnment fine */
    if (!([[NSUserDefaults standardUserDefaults] boolForKey:UDisWizard]) &&
        ([formElement.type isEqualToString:kXFormsString] ||
        [formElement.type isEqualToString:kXFormsNumber] ||
        [formElement.type isEqualToString:kXFormsDecimal])) {
        [row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
    }

    if ([formElement.type isEqualToString:kXFormsAudio]) {
        row.action.viewControllerClass = [SimpleAudioViewController class];
    }
    if ([formElement.type isEqualToString:kXFormsGPS]) {
        row.action.viewControllerClass = [MapViewController class];
        row.valueTransformer = [CLLocationValueTrasformer class];
        row.value = [[CLLocation alloc] initWithLatitude:-33 longitude:-56];
    }

    // Items
    if ([formElement.type isEqualToString:kXFormsSelect] || [formElement.type isEqualToString:kXFormsMutlipleSelect]) {
        formElement.items = [[NSMutableArray alloc] init];
        NSMutableArray *labels = [[NSMutableArray alloc] init];
        for (GDataXMLElement *item in [input elementsForName:@"xf:item"]) {
            NSString *label = [(GDataXMLElement *)([item elementsForName:@"xf:label"][0]) stringValue];
            NSString *value =[(GDataXMLElement *)([item elementsForName:@"xf:value"][0]) stringValue];
            [labels addObject:label];
            [formElement.items addObject:[XLFormOptionsObject formOptionsObjectWithValue:value displayText:label]];
        }
        row.selectorOptions = formElement.items;
    }
    
    //Locked
    if ([bindingForInput attributeForName:@"locked"]) {
        if ([[[bindingForInput attributeForName:@"locked"] stringValue] isEqualToString:@"true()"]) {
            formElement.locked = YES;
            row.disabled = @YES;
        } else {
            formElement.locked = NO;
            row.disabled = @NO;
        }
    }
    //Visible
    if ([bindingForInput attributeForName:@"visible"]) {
        if ([[[bindingForInput attributeForName:@"visible"] stringValue] isEqualToString:@"true()"]) {
            formElement.visible = YES;
            row.hidden = @NO;
        } else {
            formElement.visible = NO;
            row.hidden = @YES;
        }
    } else {
        formElement.visible = YES;
    }
    //Required
    if ([bindingForInput attributeForName:@"required"]) {
        if ([[[bindingForInput attributeForName:@"required"] stringValue] isEqualToString:@"true()"]) {
            formElement.required = YES;
            row.required = @YES;
            [XFormsParser addRedAssertres:row];
        } else {
            formElement.required = NO;
            row.required = @NO;
        }
    }
    
    NSString *nodeXPath = [[bindingForInput attributeForName:@"nodeset"] stringValue];
    GDataXMLElement *instanceNode = [instance nodesForXPath:[NSString stringWithFormat:@"/%@", nodeXPath] error:nil][0];
    formElement.XPathNode = nodeXPath;
    formElement.XMLnode = instanceNode;
    
    
    //Adding default value.. now only strings
    row.value = [XFormsParser getRowValueFromElement:formElement andValue:instanceNode.stringValue];

    if (formElement.hint && formElement.visible) {
        XLFormRowDescriptor *infoRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"info" rowType:XLFormRowDescriptorTypeInfo title:formElement.hint];
        [infoRow.cellConfig setObject:[UIColor colorWithRed:39/255.0
                                                      green:139/255.0
                                                       blue:146/255.0
                                                      alpha:1] forKey:@"backgroundColor"];
        [infoRow.cellConfig setObject:[UIColor whiteColor] forKey:@"textLabel.textColor"];
        [infoRow.cellConfig setObject:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] forKey:@"textLabel.font"];
        [section addFormRow:infoRow];
    }
    [group setObject:formElement forKey:formElement.bindID];
    [section addFormRow:row];
}

+ (GDataXMLDocument *)InjecValues:(XForms *)form {
    GDataXMLElement *model = [form.doc.rootElement elementsForName:@"xf:model"][0];
    GDataXMLElement *instance = [model elementsForName:@"xf:instance"][0];

    for (int i = 0;i < form.forms.count; i++) {
        XLFormDescriptor *formDescriptor = form.forms[i];
        NSDictionary *elements = form.groups[i];
        int index = 0;
        for (XLFormSectionDescriptor *section in formDescriptor.formSections) {
            for (XLFormRowDescriptor *row in section.formRows) {
                if ([row.tag isEqualToString:@"add"] || [row.tag isEqualToString:@"delete"] || [row.tag isEqualToString:@"info"]) {
                    continue;
                }
                XFormElement *element = elements[row.tag];
                //Second or futther repeat block
                if (!element) {
                    XFormElement *superElement;
                    for (NSString *key in elements) {
                        superElement = elements[key];
                    }
                    if (index) {
                        [[superElement parentNodeFromDoc:form.doc] addChild:superElement.XMLnode];
                        superElement.XMLnode = [[superElement parentNodeFromDoc:form.doc] elementsForName:superElement.XMLnode.name][index];
                    }
                    for (NSString *subelementKey in superElement.subElements) {
                        XFormElement *subelement = [superElement.subElements objectForKey:subelementKey];
                        NSLog(@"row tag: %@, bindID %@", row.tag, subelement.bindID);
                        if ([row.tag isEqualToString:subelement.bindID]) {
                            [XFormsParser modifyElement:subelement Value:row.value];
                            break;
                        } else if ([row.tag isEqualToString:[NSString stringWithFormat:@"%@~NEW", subelement.bindID]] && index) {
                            subelement.XMLnode = [superElement.XMLnode elementsForName:subelement.XMLnode.name][0];
                            GDataXMLNode *attrNode = [GDataXMLNode attributeWithName:@"new" stringValue:@"true()"];
                            [subelement.XMLnode addAttribute:attrNode];
                            [XFormsParser modifyElement:subelement Value:row.value];
                            break;
                        }
                    }
                    
                } else {
                    NSLog(@"element: %@, value: %@", element, row.value);
                    [XFormsParser modifyElement:element Value:row.value];
                }
            }
            index++;
        }
    }
    NSLog(@"%@", instance);
    return nil;
}

+ (id) getRowValueFromElement:(XFormElement *)formElement andValue:(NSString *) value {
    if ([formElement.type isEqualToString:kXFormsString]) {
        return value;
    } else if ([formElement.type isEqualToString:kXFormsNumber]) {
        if (![value isEqualToString:@""]) {
            return [NSNumber numberWithInteger:[value integerValue]];
        } else {
            return nil;
        }
    } else if ([formElement.type isEqualToString:kXFormsDecimal]) {
        if (![value isEqualToString:@""]) {
            return [NSNumber numberWithFloat:[value floatValue]];
        } else {
            return nil;
        }
    } else if ([formElement.type isEqualToString:kXFormsSelect] ||
               [formElement.type isEqualToString:kXFormsMutlipleSelect]) {
        for (XLFormOptionsObject *opObj in formElement.items) {
            NSString *valueOb = opObj.valueData;
            if ([valueOb isEqualToString:value]) {
                return opObj;
            }
        }
        return nil;
    } else if ([formElement.type isEqualToString:kXFormsDate] ||
               [formElement.type isEqualToString:kXFormsTime] ||
               [formElement.type isEqualToString:kXFormsDateTime]) {
         return [MRSDateUtilities DatefromXFormsString:value
                                                      type:formElement.type];
    } else if ([formElement.type isEqualToString:kXFormsBoolean]) {
        if ([value isEqualToString:@"true"]) {
            return @1;
        } else {
            return @0;
        }
    } else {
        return nil;
    }
}

+ (void)modifyElement:(XFormElement *)element Value:(id)value {
    NSLog(@"ID: %@, xml node :%@, val: %@", element.bindID, element.XMLnode, value);
    if (element && value) {
        GDataXMLElement *elementNode = element.XMLnode;
        elementNode.stringValue = [XFormsParser stringFromValue:value Type:element.type];
    }
    NSLog(@"ID: %@, xml node :%@", element.bindID, element.XMLnode);
}

+ (NSString *)stringFromValue:(id)value Type:(NSString *)type {
    if ([type isEqualToString:kXFormsString]) {
        return value;
    } else if ([type isEqualToString:kXFormsNumber] ||
               [type isEqualToString:kXFormsDecimal]) {
        return [value stringValue];
    } else if ([type isEqualToString:kXFormsBoolean]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:UDisWizard]) {
            if ([value isEqualToString:@"Yes"]) {
                return @"true";
            } else {
                return @"false";
            }
        }
        if (value) {
            return @"true";
        } else {
            return @"false";
        }
    } else if ([type isEqualToString:kXFormsDate] ||
               [type isEqualToString:kXFormsTime] ||
               [type isEqualToString:kXFormsDateTime]) {
        return [MRSDateUtilities XFormformatStringwithDate:value type:type];
    } else if ([type isEqualToString:kXFormsSelect] ||
               [type isEqualToString:kXFormsImage] ||
               [type isEqualToString:kXFormsAudio] ||
               [type isEqualToString:kXFormsGPS] ||
               [type isEqualToString:kXFormsMutlipleSelect]) {
        XLFormOptionsObject *obj = value;
        return obj.valueData;
    }
    else {
        NSLog(@"Unsupported type");
        [NSException raise:@"Invalid foo value" format:@"foo of %@ is invalid", type];
        return nil;
    }
}

+ (void)addRedAssertres:(XLFormRowDescriptor *)row {
    NSMutableAttributedString *requiredLabel = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"*%@", row.title]];
    [requiredLabel addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0, 1)];
    [row.cellConfig setObject:requiredLabel forKey:@"textLabel.attributedText"];
}
@end

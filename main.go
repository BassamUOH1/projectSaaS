package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// RequestBody يمثل الجسم المرسل في الطلب
type RequestBody struct {
	TableName string `json:"TableName"`
	ID        string `json:"id"`
	Name      string `json:"name"`
	Date      string `json:"date"`
	Pass      string `json:"pass"`
	State_P   string `json:"state_p"`
	Data_1    string `json:"data_1"`
	Data_2    string `json:"data_2"`
	Data_3    string `json:"data_3"`
	Data_4    string `json:"data_4"`
}

// generateCORSResponse تولّد استجابة مع هيدرات CORS
func generateCORSResponse(statusCode int, body []byte) events.APIGatewayProxyResponse {
	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,

		Body: string(body),
	}
}

// parseRequestBody يقوم بفك تشفير جسم الطلب
func parseRequestBody(body string) (RequestBody, error) {
	var reqBody RequestBody
	err := json.Unmarshal([]byte(body), &reqBody)
	return reqBody, err
}

// validateRequest يتحقق من وجود الحقول المطلوبة في الطلب
func validateRequest(reqBody RequestBody) error {
	var missingFields []string
	if strings.TrimSpace(reqBody.TableName) == "" {
		missingFields = append(missingFields, "TableName")
	}
	if strings.TrimSpace(reqBody.ID) == "" {
		missingFields = append(missingFields, "id")
	}
	if len(missingFields) > 0 {
		return fmt.Errorf("الحقول المطلوبة ناقصة: %s", strings.Join(missingFields, ", "))
	}
	return nil
}

func getOrCreateTable(ctx context.Context, client *dynamodb.Client, tableName string, hasSortKey bool) error {
	_, err := client.DescribeTable(ctx, &dynamodb.DescribeTableInput{
		TableName: aws.String(tableName),
	})
	if err == nil {
		log.Printf("الجدول %s موجود مسبقًا.\n", tableName)
		return nil
	}

	if strings.Contains(err.Error(), "ResourceNotFoundException") {
		log.Printf("الجدول %s غير موجود. جاري الإنشاء...\n", tableName)
		keySchema := []types.KeySchemaElement{
			{
				AttributeName: aws.String("ID"),
				KeyType:       types.KeyTypeHash,
			},
		}
		attributeDefinitions := []types.AttributeDefinition{
			{
				AttributeName: aws.String("ID"),
				AttributeType: types.ScalarAttributeTypeS,
			},
		}

		// لا تضف مفتاح فرعي (Sort Key) هنا كما هو مطلوب
		_, err = client.CreateTable(ctx, &dynamodb.CreateTableInput{
			TableName:             aws.String(tableName),
			KeySchema:             keySchema,
			AttributeDefinitions:  attributeDefinitions,
			ProvisionedThroughput: &types.ProvisionedThroughput{ReadCapacityUnits: aws.Int64(5), WriteCapacityUnits: aws.Int64(5)},
		})
		if err != nil {
			return fmt.Errorf("فشل في إنشاء الجدول: %v", err)
		}

		waiter := dynamodb.NewTableExistsWaiter(client)
		if err = waiter.Wait(ctx, &dynamodb.DescribeTableInput{TableName: aws.String(tableName)}, 5*time.Minute); err != nil {
			return fmt.Errorf("فشل انتظار جاهزية الجدول: %v", err)
		}
		log.Printf("تم إنشاء الجدول %s بنجاح.\n", tableName)
		return nil
	}
	return fmt.Errorf("خطأ غير متوقع: %v", err)
}

// createTableBigData تنشئ جدولًا وتدرج البيانات مع الحقول الإضافية
func createTableBigData(ctx context.Context, reqBody RequestBody) error {
    // تحديد وجود مفتاح فرعي
    hasSortKey := strings.TrimSpace(reqBody.Name) != ""

    // تحميل إعدادات AWS
    cfg, err := config.LoadDefaultConfig(ctx)
    if err != nil {
        return fmt.Errorf("فشل تحميل إعدادات AWS: %v", err)
    }
    client := dynamodb.NewFromConfig(cfg)

    // إنشاء الجدول أو التحقق من وجوده
    if err := getOrCreateTable(ctx, client, reqBody.TableName, hasSortKey); err != nil {
        return fmt.Errorf("فشل في إعداد الجدول: %v", err)
    }

    // إعداد العنصر مع الحقول الإضافية
    item := map[string]types.AttributeValue{
        "ID": &types.AttributeValueMemberS{Value: reqBody.ID},
    }
    if hasSortKey {
        item["Name"] = &types.AttributeValueMemberS{Value: reqBody.Name}
        item["Date"] = &types.AttributeValueMemberS{Value: reqBody.Date}
        item["Pass"] = &types.AttributeValueMemberS{Value: reqBody.Pass}
    }

    // إضافة الحقول الإضافية
    addOptionalField(item, "Data_1", reqBody.Data_1)
    addOptionalField(item, "Data_2", reqBody.Data_2)
    addOptionalField(item, "Data_3", reqBody.Data_3)
    addOptionalField(item, "Data_4", reqBody.Data_4)

    // إدخال العنصر في الجدول
    _, err = client.PutItem(ctx, &dynamodb.PutItemInput{
        TableName: aws.String(reqBody.TableName),
        Item:      item,
    })
    if err != nil {
        return fmt.Errorf("فشل في إدخال البيانات الكبيرة: %v", err)
    }
    return nil
}

// addOptionalField تُضيف حقلًا إلى العنصر إذا كانت قيمته غير فارغة
func addOptionalField(item map[string]types.AttributeValue, key, value string) {
    if strings.TrimSpace(value) != "" {
        item[key] = &types.AttributeValueMemberS{Value: value}
    }
}


// processRequest يتولى معالجة الطلب وتنفيذ العمليات على DynamoDB
func processRequest(ctx context.Context, reqBody RequestBody) error {
	// تحديد إذا كان هناك مفتاح فرعي باستخدام وجود قيمة لحقل name
	hasSortKey := strings.TrimSpace(reqBody.Name) != ""

	// تحميل إعدادات AWS وإنشاء عميل DynamoDB
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("فشل تحميل إعدادات AWS: %v", err)
	}
	client := dynamodb.NewFromConfig(cfg)

	// الحصول على الجدول أو إنشاؤه
	if err := getOrCreateTable(ctx, client, reqBody.TableName, hasSortKey); err != nil {
		return fmt.Errorf("فشل في إعداد الجدول: %v", err)
	}

	// إعداد العنصر للإدخال
	item := map[string]types.AttributeValue{
		"ID": &types.AttributeValueMemberS{Value: reqBody.ID},
	}
	if hasSortKey {
		item["Name"] = &types.AttributeValueMemberS{Value: reqBody.Name}
		item["Date"] = &types.AttributeValueMemberS{Value: reqBody.Date}
		item["Pass"] = &types.AttributeValueMemberS{Value: reqBody.Pass}
	}
	

	// إدخال العنصر في الجدول
	_, err = client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(reqBody.TableName),
		Item:      item,
	})
	if err != nil {
		return fmt.Errorf("فشل في إدخال البيانات: %v", err)
	}
	return nil
}

func getDataByID(ctx context.Context, client *dynamodb.Client, tableName string, id string) (map[string]string, error) {
	key := map[string]types.AttributeValue{
		"ID": &types.AttributeValueMemberS{Value: id},
	}

	output, err := client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key:       key,
	})
	if err != nil {
		return nil, fmt.Errorf("فشل الحصول على البيانات: %v", err)
	}

	if output.Item == nil {
		return nil, fmt.Errorf("لم يتم العثور على بيانات للـ id: %s", id)
	}

	result := make(map[string]string)
	for key, value := range output.Item {
		if strVal, ok := value.(*types.AttributeValueMemberS); ok {
			result[key] = strVal.Value
		}
	}

	return result, nil
}

// deleteItemByID تحذف عنصرًا بناءً على المفتاح الأساسي (ID)
func deleteItemByID(ctx context.Context, client *dynamodb.Client, tableName string, id string) error {
	key := map[string]types.AttributeValue{
		"ID": &types.AttributeValueMemberS{Value: id},
	}

	_, err := client.DeleteItem(ctx, &dynamodb.DeleteItemInput{
		TableName: aws.String(tableName),
		Key:       key,
	})
	if err != nil {
		return fmt.Errorf("فشل في حذف البيانات: %v", err)
	}

	return nil
}

// getAllItemsFromTable تسترجع جميع العناصر من الجدول
func getAllItemsFromTable(ctx context.Context, client *dynamodb.Client, tableName string) ([]map[string]string, error) {
	output, err := client.Scan(ctx, &dynamodb.ScanInput{
		TableName: aws.String(tableName),
	})
	if err != nil {
		return nil, fmt.Errorf("فشل في استرجاع البيانات: %v", err)
	}

	var items []map[string]string
	for _, item := range output.Items {
		parsedItem := make(map[string]string)
		for key, value := range item {
			if strVal, ok := value.(*types.AttributeValueMemberS); ok {
				parsedItem[key] = strVal.Value
			}
		}
		items = append(items, parsedItem)
	}

	return items, nil
}

// handler الدالة الأساسية التي يتم استدعاؤها عند وصول الطلب
func handler(ctx context.Context, event events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// التعامل مع طلبات OPTIONS (preflight) مباشرة لتلبية سياسات CORS
	if event.HTTPMethod == "OPTIONS" {
		emptyBody, _ := json.Marshal(map[string]interface{}{})
		return generateCORSResponse(200, emptyBody), nil
	}

	log.Printf("الحدث المُستلم: %s\n", event.Body)
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		errorBody, _ := json.Marshal(map[string]string{"error": "فشل تحميل إعدادات AWS"})
		return generateCORSResponse(500, errorBody), nil
	}
	client := dynamodb.NewFromConfig(cfg)

	// فك تشفير جسم الطلب
	reqBody, err := parseRequestBody(event.Body)
	if err != nil {
		errorBody, _ := json.Marshal(map[string]string{"error": "جسم الطلب غير صالح"})
		return generateCORSResponse(400, errorBody), nil
	}

	switch reqBody.State_P {
	case "1": // INSERT DATA & CREATE TABLE
		if err := validateRequest(reqBody); err != nil {
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(400, errorBody), nil
		}

		if err := processRequest(ctx, reqBody); err != nil {
			log.Printf("خطأ في معالجة الطلب: %v\n", err)
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(500, errorBody), nil
		}

		successBody, _ := json.Marshal(map[string]string{"message": "تم إدخال البيانات بنجاح"})
		return generateCORSResponse(200, successBody), nil

	case "2": // GET DATA
		item, err := getDataByID(ctx, client, reqBody.TableName, reqBody.ID)
		if err != nil {
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(404, errorBody), nil
		}

		responseBody, err := json.Marshal(item)
		if err != nil {
			errorBody, _ := json.Marshal(map[string]string{"error": "فشل تحويل البيانات"})
			return generateCORSResponse(500, errorBody), nil
		}

		return generateCORSResponse(200, responseBody), nil

	case "3": // DELETE ITEM
		if err := validateRequest(reqBody); err != nil {
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(400, errorBody), nil
		}

		if err := deleteItemByID(ctx, client, reqBody.TableName, reqBody.ID); err != nil {
			log.Printf("خطأ في حذف البيانات: %v\n", err)
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(500, errorBody), nil
		}

		successBody, _ := json.Marshal(map[string]string{"message": "تم حذف البيانات بنجاح"})
		return generateCORSResponse(200, successBody), nil

	case "4": // GET ALL ITEMS
		if strings.TrimSpace(reqBody.TableName) == "" {
			errorBody, _ := json.Marshal(map[string]string{"error": "اسم الجدول مطلوب"})
			return generateCORSResponse(400, errorBody), nil
		}

		items, err := getAllItemsFromTable(ctx, client, reqBody.TableName)
		if err != nil {
			log.Printf("خطأ في استرجاع البيانات: %v\n", err)
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(500, errorBody), nil
		}

		if len(items) == 0 {
			errorBody, _ := json.Marshal(map[string]string{"message": "لا توجد بيانات في الجدول"})
			return generateCORSResponse(200, errorBody), nil
		}

		responseBody, err := json.Marshal(items)
		if err != nil {
			errorBody, _ := json.Marshal(map[string]string{"error": "فشل تحويل البيانات"})
			return generateCORSResponse(500, errorBody), nil
		}

		return generateCORSResponse(200, responseBody), nil
		case "5": // CREATE TABLE WITH BIG DATA
		if err := validateRequest(reqBody); err != nil {
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(400, errorBody), nil
		}
	
		if err := createTableBigData(ctx, reqBody); err != nil {
			log.Printf("خطأ في إنشاء الجدول وإدخال البيانات الكبيرة: %v\n", err)
			errorBody, _ := json.Marshal(map[string]string{"error": err.Error()})
			return generateCORSResponse(500, errorBody), nil
		}
	
		successBody, _ := json.Marshal(map[string]string{"message": "تم إنشاء الجدول وإدخال البيانات الكبيرة بنجاح"})
		return generateCORSResponse(200, successBody), nil
		
	default:
		errorBody, _ := json.Marshal(map[string]string{"error": "حالة غير معروفة"})
		return generateCORSResponse(400, errorBody), nil
	}
}

func main() {
	lambda.Start(handler)
}

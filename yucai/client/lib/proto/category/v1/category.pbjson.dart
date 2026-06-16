// This is a generated file - do not edit.
//
// Generated from category/v1/category.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

import 'package:protobuf/well_known_types/google/protobuf/empty.pbjson.dart'
    as $2;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pbjson.dart'
    as $0;

import '../../common/v1/pagination.pbjson.dart' as $1;

@$core.Deprecated('Use categoryTypeDescriptor instead')
const CategoryType$json = {
  '1': 'CategoryType',
  '2': [
    {'1': 'CATEGORY_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'CATEGORY_TYPE_INCOME', '2': 1},
    {'1': 'CATEGORY_TYPE_EXPENSE', '2': 2},
  ],
};

/// Descriptor for `CategoryType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List categoryTypeDescriptor = $convert.base64Decode(
    'CgxDYXRlZ29yeVR5cGUSHQoZQ0FURUdPUllfVFlQRV9VTlNQRUNJRklFRBAAEhgKFENBVEVHT1'
    'JZX1RZUEVfSU5DT01FEAESGQoVQ0FURUdPUllfVFlQRV9FWFBFTlNFEAI=');

@$core.Deprecated('Use categoryDTODescriptor instead')
const CategoryDTO$json = {
  '1': 'CategoryDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'category_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.category.v1.CategoryType',
      '10': 'categoryType'
    },
    {'1': 'icon', '3': 4, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 5, '4': 1, '5': 9, '10': 'color'},
    {'1': 'parent_id', '3': 6, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'is_system', '3': 7, '4': 1, '5': 8, '10': 'isSystem'},
    {'1': 'sort_order', '3': 8, '4': 1, '5': 5, '10': 'sortOrder'},
    {'1': 'version', '3': 9, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `CategoryDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryDTODescriptor = $convert.base64Decode(
    'CgtDYXRlZ29yeURUTxIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRJECg1jYX'
    'RlZ29yeV90eXBlGAMgASgOMh8ueXVjYWkuY2F0ZWdvcnkudjEuQ2F0ZWdvcnlUeXBlUgxjYXRl'
    'Z29yeVR5cGUSEgoEaWNvbhgEIAEoCVIEaWNvbhIUCgVjb2xvchgFIAEoCVIFY29sb3ISGwoJcG'
    'FyZW50X2lkGAYgASgJUghwYXJlbnRJZBIbCglpc19zeXN0ZW0YByABKAhSCGlzU3lzdGVtEh0K'
    'CnNvcnRfb3JkZXIYCCABKAVSCXNvcnRPcmRlchIYCgd2ZXJzaW9uGAkgASgDUgd2ZXJzaW9uEj'
    'kKCmNyZWF0ZWRfYXQYCiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVk'
    'QXQSOQoKdXBkYXRlZF9hdBgLIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXVwZG'
    'F0ZWRBdA==');

@$core.Deprecated('Use createCategoryRequestDescriptor instead')
const CreateCategoryRequest$json = {
  '1': 'CreateCategoryRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'category_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.category.v1.CategoryType',
      '10': 'categoryType'
    },
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 4, '4': 1, '5': 9, '10': 'color'},
    {'1': 'parent_id', '3': 5, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'sort_order', '3': 6, '4': 1, '5': 5, '10': 'sortOrder'},
  ],
};

/// Descriptor for `CreateCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createCategoryRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVDYXRlZ29yeVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRJECg1jYXRlZ29yeV'
    '90eXBlGAIgASgOMh8ueXVjYWkuY2F0ZWdvcnkudjEuQ2F0ZWdvcnlUeXBlUgxjYXRlZ29yeVR5'
    'cGUSEgoEaWNvbhgDIAEoCVIEaWNvbhIUCgVjb2xvchgEIAEoCVIFY29sb3ISGwoJcGFyZW50X2'
    'lkGAUgASgJUghwYXJlbnRJZBIdCgpzb3J0X29yZGVyGAYgASgFUglzb3J0T3JkZXI=');

@$core.Deprecated('Use updateCategoryRequestDescriptor instead')
const UpdateCategoryRequest$json = {
  '1': 'UpdateCategoryRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 4, '4': 1, '5': 9, '10': 'color'},
    {'1': 'sort_order', '3': 5, '4': 1, '5': 5, '10': 'sortOrder'},
    {'1': 'version', '3': 6, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateCategoryRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVDYXRlZ29yeVJlcXVlc3QSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG'
    '5hbWUSEgoEaWNvbhgDIAEoCVIEaWNvbhIUCgVjb2xvchgEIAEoCVIFY29sb3ISHQoKc29ydF9v'
    'cmRlchgFIAEoBVIJc29ydE9yZGVyEhgKB3ZlcnNpb24YBiABKANSB3ZlcnNpb24=');

@$core.Deprecated('Use deleteCategoryRequestDescriptor instead')
const DeleteCategoryRequest$json = {
  '1': 'DeleteCategoryRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCategoryRequestDescriptor = $convert
    .base64Decode('ChVEZWxldGVDYXRlZ29yeVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use getCategoryRequestDescriptor instead')
const GetCategoryRequest$json = {
  '1': 'GetCategoryRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCategoryRequestDescriptor =
    $convert.base64Decode('ChJHZXRDYXRlZ29yeVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use listCategoriesRequestDescriptor instead')
const ListCategoriesRequest$json = {
  '1': 'ListCategoriesRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {
      '1': 'category_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.category.v1.CategoryType',
      '10': 'categoryType'
    },
    {'1': 'search', '3': 3, '4': 1, '5': 9, '10': 'search'},
  ],
};

/// Descriptor for `ListCategoriesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCategoriesRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0Q2F0ZWdvcmllc1JlcXVlc3QSMAoEcGFnZRgBIAEoCzIcLnl1Y2FpLmNvbW1vbi52MS'
    '5QYWdlUmVxdWVzdFIEcGFnZRJECg1jYXRlZ29yeV90eXBlGAIgASgOMh8ueXVjYWkuY2F0ZWdv'
    'cnkudjEuQ2F0ZWdvcnlUeXBlUgxjYXRlZ29yeVR5cGUSFgoGc2VhcmNoGAMgASgJUgZzZWFyY2'
    'g=');

@$core.Deprecated('Use listCategoriesResponseDescriptor instead')
const ListCategoriesResponse$json = {
  '1': 'ListCategoriesResponse',
  '2': [
    {
      '1': 'categories',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.category.v1.CategoryDTO',
      '10': 'categories'
    },
    {
      '1': 'page',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageResponse',
      '10': 'page'
    },
  ],
};

/// Descriptor for `ListCategoriesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCategoriesResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0Q2F0ZWdvcmllc1Jlc3BvbnNlEj4KCmNhdGVnb3JpZXMYASADKAsyHi55dWNhaS5jYX'
    'RlZ29yeS52MS5DYXRlZ29yeURUT1IKY2F0ZWdvcmllcxIxCgRwYWdlGAIgASgLMh0ueXVjYWku'
    'Y29tbW9uLnYxLlBhZ2VSZXNwb25zZVIEcGFnZQ==');

@$core.Deprecated('Use categoryResponseDescriptor instead')
const CategoryResponse$json = {
  '1': 'CategoryResponse',
  '2': [
    {
      '1': 'category',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.category.v1.CategoryDTO',
      '10': 'category'
    },
  ],
};

/// Descriptor for `CategoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryResponseDescriptor = $convert.base64Decode(
    'ChBDYXRlZ29yeVJlc3BvbnNlEjoKCGNhdGVnb3J5GAEgASgLMh4ueXVjYWkuY2F0ZWdvcnkudj'
    'EuQ2F0ZWdvcnlEVE9SCGNhdGVnb3J5');

const $core.Map<$core.String, $core.dynamic> CategoryServiceBase$json = {
  '1': 'CategoryService',
  '2': [
    {
      '1': 'CreateCategory',
      '2': '.yucai.category.v1.CreateCategoryRequest',
      '3': '.yucai.category.v1.CategoryResponse'
    },
    {
      '1': 'UpdateCategory',
      '2': '.yucai.category.v1.UpdateCategoryRequest',
      '3': '.yucai.category.v1.CategoryResponse'
    },
    {
      '1': 'DeleteCategory',
      '2': '.yucai.category.v1.DeleteCategoryRequest',
      '3': '.google.protobuf.Empty'
    },
    {
      '1': 'ListCategories',
      '2': '.yucai.category.v1.ListCategoriesRequest',
      '3': '.yucai.category.v1.ListCategoriesResponse'
    },
    {
      '1': 'GetCategory',
      '2': '.yucai.category.v1.GetCategoryRequest',
      '3': '.yucai.category.v1.CategoryResponse'
    },
  ],
};

@$core.Deprecated('Use categoryServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    CategoryServiceBase$messageJson = {
  '.yucai.category.v1.CreateCategoryRequest': CreateCategoryRequest$json,
  '.yucai.category.v1.CategoryResponse': CategoryResponse$json,
  '.yucai.category.v1.CategoryDTO': CategoryDTO$json,
  '.google.protobuf.Timestamp': $0.Timestamp$json,
  '.yucai.category.v1.UpdateCategoryRequest': UpdateCategoryRequest$json,
  '.yucai.category.v1.DeleteCategoryRequest': DeleteCategoryRequest$json,
  '.google.protobuf.Empty': $2.Empty$json,
  '.yucai.category.v1.ListCategoriesRequest': ListCategoriesRequest$json,
  '.yucai.common.v1.PageRequest': $1.PageRequest$json,
  '.yucai.category.v1.ListCategoriesResponse': ListCategoriesResponse$json,
  '.yucai.common.v1.PageResponse': $1.PageResponse$json,
  '.yucai.category.v1.GetCategoryRequest': GetCategoryRequest$json,
};

/// Descriptor for `CategoryService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List categoryServiceDescriptor = $convert.base64Decode(
    'Cg9DYXRlZ29yeVNlcnZpY2USXwoOQ3JlYXRlQ2F0ZWdvcnkSKC55dWNhaS5jYXRlZ29yeS52MS'
    '5DcmVhdGVDYXRlZ29yeVJlcXVlc3QaIy55dWNhaS5jYXRlZ29yeS52MS5DYXRlZ29yeVJlc3Bv'
    'bnNlEl8KDlVwZGF0ZUNhdGVnb3J5EigueXVjYWkuY2F0ZWdvcnkudjEuVXBkYXRlQ2F0ZWdvcn'
    'lSZXF1ZXN0GiMueXVjYWkuY2F0ZWdvcnkudjEuQ2F0ZWdvcnlSZXNwb25zZRJSCg5EZWxldGVD'
    'YXRlZ29yeRIoLnl1Y2FpLmNhdGVnb3J5LnYxLkRlbGV0ZUNhdGVnb3J5UmVxdWVzdBoWLmdvb2'
    'dsZS5wcm90b2J1Zi5FbXB0eRJlCg5MaXN0Q2F0ZWdvcmllcxIoLnl1Y2FpLmNhdGVnb3J5LnYx'
    'Lkxpc3RDYXRlZ29yaWVzUmVxdWVzdBopLnl1Y2FpLmNhdGVnb3J5LnYxLkxpc3RDYXRlZ29yaW'
    'VzUmVzcG9uc2USWQoLR2V0Q2F0ZWdvcnkSJS55dWNhaS5jYXRlZ29yeS52MS5HZXRDYXRlZ29y'
    'eVJlcXVlc3QaIy55dWNhaS5jYXRlZ29yeS52MS5DYXRlZ29yeVJlc3BvbnNl');

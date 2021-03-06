// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:googleapis/people/v1.dart' as contact;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'models.dart';

/// The order in which a list of contact connections should be sorted.
enum ContactSortOrder {
  /// Sort people by when they were changed; older entries first.
  lastModifiedAscending,

  /// Sort people by first name.
  firstNameAscending,

  /// Sort people by last name
  lastNameAscending,
}

/// The interface to the Google Contacts REST API.
class ContactAPI {
  /// Google OAuth scopes.
  List<String> scopes;
  Client _baseClient;
  AutoRefreshingAuthClient _client;
  contact.PeopleApi _contactApi;

  /// The [ContactAPI] constructor
  ContactAPI({
    @required String id,
    @required String secret,
    @required String token,
    @required DateTime expiry,
    @required String refreshToken,
    @required this.scopes,
  }) {
    assert(id != null);
    assert(secret != null);
    assert(token != null);
    assert(expiry != null);
    assert(refreshToken != null);

    ClientId clientId = new ClientId(id, secret);
    AccessToken accessToken = new AccessToken('Bearer', token, expiry);
    AccessCredentials credentials =
        new AccessCredentials(accessToken, refreshToken, scopes);
    _baseClient = new Client();
    _client = autoRefreshingClient(clientId, credentials, _baseClient);
    _contactApi = new contact.PeopleApi(_client);
  }

  /// Create an instance of [ContactAPI] by loading a config file.
  static Future<ContactAPI> fromConfig(String src) async {
    // TODO(youngseokyoon): restore the config.
    // https://fuchsia.atlassian.net/browse/SO-285
    // ignore: MISSING_REQUIRED_PARAM
    return new ContactAPI();
    // Config config = await Config.read(src);
    // List<String> keys = <String>[
    //   'oauth_id',
    //   'oauth_secret',
    //   'oauth_token',
    //   'oauth_token_expiry',
    //   'oauth_refresh_token',
    // ];
    // config.validate(keys);
    //
    // return new ContactAPI(
    //     id: config.get('oauth_id'),
    //     secret: config.get('oauth_secret'),
    //     token: config.get('oauth_token'),
    //     expiry: DateTime.parse(config.get('oauth_token_expiry')),
    //     refreshToken: config.get('oauth_refresh_token'),
    //     scopes: config.scopes);
  }

  /// Gets a [Contact] from the Google People API
  /// Use the ID value of "me" to retrieve the current authenticated user
  Future<Contact> getUser(String id) async {
    assert(id != null);
    contact.Person person = await _contactApi.people.get(id);
    return new Contact(
      id: person.resourceName,
      displayName: person.names.first?.displayName,
      givenName: person.names.first?.givenName,
      familyName: person.names.first?.familyName,
      addresses: person.addresses?.map(_address)?.toList(),
      emailAddresses: person.emailAddresses?.map(_email)?.toList(),
      phoneNumbers: person.phoneNumbers?.map(_phoneNumber)?.toList(),
      photoUrl: person.photos?.first?.url,
      backgroundImageUrl: person.coverPhotos?.first?.url,
    );
  }

  /// Retrieves the contacts that are "connections" of the currently
  /// authenticated user.
  Future<List<Contact>> getConnections({
    ContactSortOrder sortOrder,
    int pageSize,
    String pageToken,
  }) async {
    String order;
    switch (sortOrder) {
      case ContactSortOrder.firstNameAscending:
        order = 'FIRST_NAME_ASCENDING';
        break;
      case ContactSortOrder.lastNameAscending:
        order = 'LAST_NAME_ASCENDING';
        break;
      case ContactSortOrder.lastModifiedAscending:
        order = 'LAST_MODIFIED_ASCENDING';
        break;
    }
    contact.ListConnectionsResponse response =
        await _contactApi.people.connections.list(
      'people/me',
      sortOrder: order,
      pageSize: pageSize ?? 100,
      pageToken: pageToken,
    );

    return response.connections.map(_contact).toList();
  }

  /// Maps a Google People API person to the Contact Model
  Contact _contact(contact.Person person) {
    return new Contact(
      id: person.resourceName,
      displayName: person.names.first?.displayName,
      givenName: person.names.first?.givenName,
      familyName: person.names.first?.familyName,
      addresses: person.addresses?.map(_address)?.toList(),
      emailAddresses: person.emailAddresses?.map(_email)?.toList(),
      phoneNumbers: person.phoneNumbers?.map(_phoneNumber)?.toList(),
      photoUrl: person.photos?.first?.url,
      backgroundImageUrl: person.coverPhotos?.first?.url,
    );
  }

  /// Maps a Google People API address to the Contacts Address model
  Address _address(contact.Address address) {
    return new Address(
      city: address.city,
      street: address.streetAddress,
      region: address.region,
      postalCode: address.postalCode,
      country: address.country,
      countryCode: address.countryCode,
      label: address.formattedType,
    );
  }

  /// Maps a Google People API email address to the Contacts Email Address model
  EmailAddress _email(contact.EmailAddress emailAddress) {
    return new EmailAddress(
      value: emailAddress.value,
      label: emailAddress.formattedType,
    );
  }

  /// Maps a Google People API phone number to the Contacts Phone Number Model
  PhoneNumber _phoneNumber(contact.PhoneNumber phoneNumber) {
    return new PhoneNumber(
      number: phoneNumber.value,
      label: phoneNumber.formattedType,
    );
  }
}
